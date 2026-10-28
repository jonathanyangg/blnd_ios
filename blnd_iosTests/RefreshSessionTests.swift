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

    @Test func checkSession401SignsOut() async {
        let snapshot = KeychainSnapshot.capture()
        let previousSession = APIClient.shared.session
        APIClient.shared.session = RefreshHTTPStub.install(.always(.status(401)))
        KeychainManager.save(key: "accessToken", string: "old-access")
        KeychainManager.save(key: "refreshToken", string: "old-refresh")
        KeychainManager.save(key: "userId", string: "old-user")
        let auth = AuthState()
        auth.phase = .authenticated
        defer {
            APIClient.shared.session = previousSession
            snapshot.restore()
        }

        await auth.checkSession(retryDelays: [0, 0, 0])
        await waitUntilSignedOut()

        #expect(auth.phase == .unauthenticated)
        #expect(KeychainManager.readString(key: "accessToken") == nil)
        #expect(KeychainManager.readString(key: "refreshToken") == nil)
    }

    @Test func failedCheckKeepsSignedInSession() async {
        await check(
            refresh: .always(.status(503)),
            meStatus: 500,
            signedIn: true
        ) { auth in
            #expect(auth.phase == .authenticated)
            #expect(KeychainManager.readString(key: "accessToken") == "old-access")
            #expect(KeychainManager.readString(key: "refreshToken") == "old-refresh")
            #expect(KeychainManager.readString(key: "userId") == "old-user")
        }
    }

    @Test func failedCheckOnColdStartKeepsTokens() async {
        await check(
            refresh: .always(.status(503)),
            meStatus: 500,
            signedIn: false
        ) { auth in
            #expect(auth.phase == .unauthenticated)
            #expect(KeychainManager.readString(key: "accessToken") == "old-access")
            #expect(KeychainManager.readString(key: "userId") == "old-user")
        }
    }

    @Test func staleRejectedRefreshDoesNotLogOutReplacement() async {
        let snapshot = KeychainSnapshot.capture()
        let previousSession = APIClient.shared.session
        APIClient.shared.session = RefreshHTTPStub.install(.always(.status(401)))
        RefreshHTTPStub.hangNextRefresh()
        KeychainManager.save(key: "accessToken", string: "old-access")
        KeychainManager.save(key: "refreshToken", string: "old-refresh")
        KeychainManager.save(key: "userId", string: "old-user")
        let auth = AuthState()
        auth.phase = .authenticated
        defer {
            RefreshHTTPStub.releaseRefresh()
            APIClient.shared.session = previousSession
            snapshot.restore()
        }

        let check = Task { await auth.checkSession(retryDelays: [0, 0, 0]) }
        await waitUntil { RefreshHTTPStub.refreshEntered == 1 }
        KeychainManager.save(key: "accessToken", string: "newer-access")
        KeychainManager.save(key: "refreshToken", string: "newer-refresh")
        KeychainManager.save(key: "userId", string: "newer-user")
        auth.bumpSessionGeneration()
        auth.phase = .authenticated
        RefreshHTTPStub.releaseRefresh()
        await check.value
        await flushMain()

        #expect(auth.phase == .authenticated)
        #expect(KeychainManager.readString(key: "accessToken") == "newer-access")
        #expect(KeychainManager.readString(key: "refreshToken") == "newer-refresh")
        #expect(KeychainManager.readString(key: "userId") == "newer-user")
    }

    @Test func concurrentChecksShareOneSessionRead() async {
        let snapshot = KeychainSnapshot.capture()
        let previousSession = APIClient.shared.session
        APIClient.shared.session = RefreshHTTPStub.install(.always(.status(503)))
        RefreshHTTPStub.meStatus = 500
        RefreshHTTPStub.hangNextMe()
        KeychainManager.save(key: "accessToken", string: "old-access")
        KeychainManager.save(key: "refreshToken", string: "old-refresh")
        KeychainManager.save(key: "userId", string: "old-user")
        let auth = AuthState()
        auth.phase = .authenticated
        defer {
            RefreshHTTPStub.releaseMe()
            APIClient.shared.session = previousSession
            snapshot.restore()
        }

        let first = Task { await auth.checkSession(retryDelays: [0, 0, 0]) }
        await waitUntil { RefreshHTTPStub.meEntered == 1 }
        let second = Task { await auth.checkSession(retryDelays: [0, 0, 0]) }
        await Task.yield()
        await Task.yield()
        #expect(RefreshHTTPStub.meCount == 1)
        RefreshHTTPStub.releaseMe()
        await first.value
        await second.value

        #expect(RefreshHTTPStub.meCount == 4)
        #expect(auth.phase == .authenticated)
        #expect(KeychainManager.readString(key: "accessToken") == "old-access")
    }

    private func check(
        refresh: RefreshHTTPStub.Script,
        meStatus: Int,
        signedIn: Bool,
        verify: (AuthState) -> Void
    ) async {
        let snapshot = KeychainSnapshot.capture()
        let previousSession = APIClient.shared.session
        APIClient.shared.session = RefreshHTTPStub.install(refresh)
        RefreshHTTPStub.meStatus = meStatus
        KeychainManager.save(key: "accessToken", string: "old-access")
        KeychainManager.save(key: "refreshToken", string: "old-refresh")
        KeychainManager.save(key: "userId", string: "old-user")
        let auth = AuthState()
        if signedIn { auth.phase = .authenticated }
        defer {
            APIClient.shared.session = previousSession
            snapshot.restore()
        }

        await auth.checkSession(retryDelays: [0, 0, 0])
        await flushMain()
        verify(auth)
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0 ..< 100 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        Issue.record("timed out")
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
    private static var hangRefresh = false
    private static var refreshReleased = true
    private static var hangMe = false
    private static var meReleased = true

    static var refreshCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return refreshCountStorage
    }

    static var meStatus = 200
    static var meCount = 0
    static var refreshEntered = 0
    static var meEntered = 0

    static func hangNextRefresh() {
        lock.lock()
        hangRefresh = true
        refreshReleased = false
        refreshEntered = 0
        lock.unlock()
    }

    static func releaseRefresh() {
        lock.lock()
        refreshReleased = true
        lock.unlock()
    }

    static func hangNextMe() {
        lock.lock()
        hangMe = true
        meReleased = false
        meEntered = 0
        lock.unlock()
    }

    static func releaseMe() {
        lock.lock()
        meReleased = true
        lock.unlock()
    }

    static func install(_ script: Script) -> URLSession {
        lock.lock()
        self.script = script
        refreshCountStorage = 0
        hangRefresh = false
        refreshReleased = true
        hangMe = false
        meReleased = true
        meStatus = 200
        meCount = 0
        refreshEntered = 0
        meEntered = 0
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
        let path = request.url?.path ?? ""
        if path.hasSuffix("/auth/me") {
            let status = Self.beginMe()
            finish(status: status, body: Data(#"{"detail":"unavailable"}"#.utf8))
            return
        }
        guard path.hasSuffix("/auth/refresh") else {
            finish(status: 200, body: Data("{}".utf8))
            return
        }
        Self.waitForRefreshRelease()

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

    private static func beginMe() -> Int {
        let hang: Bool
        lock.lock()
        meCount += 1
        hang = hangMe
        if hang {
            hangMe = false
            meEntered += 1
        }
        let status = meStatus
        lock.unlock()
        if hang { waitUntilReleased { meReleased } }
        return status
    }

    private static func waitForRefreshRelease() {
        let hang: Bool
        lock.lock()
        hang = hangRefresh
        if hang {
            hangRefresh = false
            refreshEntered += 1
        }
        lock.unlock()
        if hang { waitUntilReleased { refreshReleased } }
    }

    private static func waitUntilReleased(_ done: () -> Bool) {
        while true {
            lock.lock()
            let released = done()
            lock.unlock()
            if released { return }
            Thread.sleep(forTimeInterval: 0.01)
        }
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
