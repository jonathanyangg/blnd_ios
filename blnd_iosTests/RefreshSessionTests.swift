@testable import blnd_ios
import Foundation
import Testing

/// Fakes `POST /auth/refresh` and checks the session decision.
/// 401 signs the user out and is not retried. 403, 500, 503, and network
/// errors keep the stored session and retry the refresh call.
@MainActor
@Suite(.serialized)
struct RefreshSessionTests {
    @Test func refresh401SignsOut() async {
        await exercise(.always(.status(401)), expects: .signedOut)
    }

    @Test(arguments: [403, 500, 503])
    func refreshServerErrorKeepsSessionAndRetries(status: Int) async {
        await exercise(
            .failOnceThenSucceed(.status(status)),
            expects: .recovered
        )
    }

    @Test func refreshNetworkErrorKeepsSessionAndRetries() async {
        await exercise(.failOnceThenSucceed(.network), expects: .recovered)
    }

    @Test func refresh503KeepsSessionWhenRetryAlsoFails() async {
        await exercise(.always(.status(503)), expects: .kept)
    }

    private func exercise(
        _ script: RefreshHTTPStub.Script,
        expects: SessionExpectation
    ) async {
        let snapshot = KeychainSnapshot.capture()
        let previousSession = APIClient.shared.session
        APIClient.shared.session = RefreshHTTPStub.install(script)
        KeychainManager.save(key: "accessToken", string: "old-access")
        KeychainManager.save(key: "refreshToken", string: "old-refresh")
        KeychainManager.save(key: "userId", string: "old-user")
        let auth = AuthState()
        auth.phase = .authenticated

        defer {
            APIClient.shared.session = previousSession
            snapshot.restore()
        }

        do {
            try await APIClient.shared.refreshTokens()
            if expects != .recovered {
                Issue.record("Refresh should fail, got success")
            }
        } catch let error as APIError {
            switch expects {
            case .signedOut:
                if case .unauthorized = error {} else {
                    Issue.record("Expected unauthorized, got \(error)")
                }
            case .kept:
                if case .refreshUnavailable = error {} else {
                    Issue.record("Expected refreshUnavailable, got \(error)")
                }
            case .recovered:
                Issue.record("Transient refresh should succeed on retry, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error \(error)")
        }

        await flushMain()
        if expects == .signedOut {
            await waitUntilSignedOut()
        }

        await assertRefreshResult(expects, auth: auth)
    }

    private func assertRefreshResult(
        _ expects: SessionExpectation,
        auth: AuthState
    ) async {
        switch expects {
        case .signedOut:
            #expect(RefreshHTTPStub.refreshCount == 1)
            #expect(auth.phase == .unauthenticated)
            #expect(KeychainManager.readString(key: "accessToken") == nil)
            #expect(KeychainManager.readString(key: "refreshToken") == nil)
        case .recovered:
            #expect(RefreshHTTPStub.refreshCount >= 2)
            #expect(auth.phase == .authenticated)
            #expect(KeychainManager.readString(key: "accessToken") == "new-access")
            #expect(KeychainManager.readString(key: "refreshToken") == "new-refresh")
        case .kept:
            #expect(RefreshHTTPStub.refreshCount >= 2)
            #expect(auth.phase == .authenticated)
            #expect(KeychainManager.readString(key: "accessToken") == "old-access")
            #expect(KeychainManager.readString(key: "refreshToken") == "old-refresh")
        }
    }

    /// Logout is posted onto the main queue. Drain it before asserting.
    private func flushMain() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    private func waitUntilSignedOut() async {
        for _ in 0 ..< 40 {
            if KeychainManager.readString(key: "accessToken") == nil { return }
            await flushMain()
        }
    }
}

private enum SessionExpectation {
    case signedOut
    case recovered
    case kept
}

private struct KeychainSnapshot {
    let access: String?
    let refresh: String?
    let userId: String?

    static func capture() -> KeychainSnapshot {
        KeychainSnapshot(
            access: KeychainManager.readString(key: "accessToken"),
            refresh: KeychainManager.readString(key: "refreshToken"),
            userId: KeychainManager.readString(key: "userId")
        )
    }

    func restore() {
        restore("accessToken", access)
        restore("refreshToken", refresh)
        restore("userId", userId)
    }

    private func restore(_ key: String, _ value: String?) {
        if let value {
            KeychainManager.save(key: key, string: value)
        } else {
            KeychainManager.delete(key: key)
        }
    }
}

/// URLProtocol stand-in for `POST /auth/refresh`.
final class RefreshHTTPStub: URLProtocol, @unchecked Sendable {
    enum Failure: Sendable {
        case status(Int)
        case network
    }

    enum Script: Sendable {
        case always(Failure)
        case failOnceThenSucceed(Failure)
    }

    private static let lock = NSLock()
    private static var script = Script.always(.status(401))
    private static var refreshCountStorage = 0

    static var refreshCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return refreshCountStorage
    }

    static func install(_ script: Script) -> URLSession {
        lock.lock()
        self.script = script
        refreshCountStorage = 0
        lock.unlock()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshHTTPStub.self]
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard request.url?.path.hasSuffix("/auth/refresh") == true else {
            finish(status: 200, body: Data("{}".utf8))
            return
        }

        let (count, script) = Self.beginRefresh()
        guard Self.shouldFail(count: count, script: script) else {
            let body = Data(
                #"{"access_token":"new-access","refresh_token":"new-refresh","user_id":"user-1"}"#
                    .utf8
            )
            finish(status: 200, body: body)
            return
        }

        switch Self.failure(of: script) {
        case let .status(status):
            finish(
                status: status,
                body: Data(#"{"detail":"unavailable"}"#.utf8)
            )
        case .network:
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.networkConnectionLost)
            )
        }
    }

    override func stopLoading() {}

    private static func beginRefresh() -> (Int, Script) {
        lock.lock()
        defer { lock.unlock() }
        refreshCountStorage += 1
        return (refreshCountStorage, script)
    }

    private static func shouldFail(count: Int, script: Script) -> Bool {
        switch script {
        case .always:
            true
        case .failOnceThenSucceed:
            count == 1
        }
    }

    private static func failure(of script: Script) -> Failure {
        switch script {
        case let .always(failure), let .failOnceThenSucceed(failure):
            failure
        }
    }

    private func finish(status: Int, body: Data) {
        guard
            let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
