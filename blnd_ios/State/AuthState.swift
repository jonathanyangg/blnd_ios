import Foundation
import RevenueCat

enum AuthPhase {
    case unauthenticated
    case onboardingPending
    case authenticated
}

@Observable
class AuthState {
    var phase: AuthPhase = .unauthenticated
    var isCheckingSession: Bool
    var currentUser: UserResponse?
    var isLoading = false
    var error: String?
    var showPaywall = false

    var isPremium: Bool {
        currentUser?.isPremium ?? false
    }

    /// In-flight session check. Overlapping calls share this task.
    private var sessionCheck: Task<Void, Never>?
    /// Bumped when a login or logout replaces the session a check started with.
    private var sessionGeneration = 0
    private let sessionCheckLock = NSLock()
    private var logoutObserver: NSObjectProtocol?

    init() {
        isCheckingSession =
            KeychainManager.readString(key: "accessToken") != nil
        logoutObserver = NotificationCenter.default.addObserver(
            forName: APIClient.forceLogoutNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logout()
        }
    }

    deinit {
        if let logoutObserver {
            NotificationCenter.default.removeObserver(logoutObserver)
        }
    }

    /// Drops an in-flight `checkSession` so it cannot log out a session that
    /// was stored after the check began.
    func bumpSessionGeneration() {
        sessionCheckLock.lock()
        sessionGeneration += 1
        sessionCheckLock.unlock()
    }

    /// Resolve auth phase on cold launch by checking the user's profile via GET /auth/me.
    /// If tokens exist but the user has no username, they need onboarding.
    ///
    /// Overlapping calls share one check. A result is applied only when the
    /// session generation is still the one this check started with, and a
    /// transport failure never demotes a session that is already signed in.
    func checkSession(retryDelays: [TimeInterval] = [2, 5, 10]) async {
        let task: Task<Void, Never> = sessionCheckLock.withLock {
            if let sessionCheck { return sessionCheck }
            let generation = sessionGeneration
            let created = Task {
                await Task.yield()
                await self.runCheckSession(generation: generation, retryDelays: retryDelays)
            }
            sessionCheck = created
            return created
        }
        await task.value
        sessionCheckLock.withLock {
            if sessionCheck == task { sessionCheck = nil }
        }
    }

    private func isCurrentSession(_ generation: Int) -> Bool {
        sessionCheckLock.withLock { sessionGeneration == generation }
    }

    private func runCheckSession(generation: Int, retryDelays: [TimeInterval]) async {
        defer { isCheckingSession = false }

        guard KeychainManager.readString(key: "accessToken") != nil else {
            guard isCurrentSession(generation) else { return }
            phase = .unauthenticated
            return
        }

        // 401 rejects this session. Anything else keeps the tokens and falls
        // through to /auth/me, which retries below.
        do {
            try await APIClient.shared.refreshTokens()
        } catch APIError.unauthorized {
            guard isCurrentSession(generation) else { return }
            phase = .unauthenticated
            return
        } catch {
            // 403, 500, 503, or a network error. Tokens stay in the Keychain.
        }

        do {
            let user = try await AuthAPI.me()
            guard isCurrentSession(generation) else { return }
            await applyCheckedSession(user)
        } catch APIError.unauthorized {
            guard isCurrentSession(generation) else { return }
            phase = .unauthenticated
        } catch {
            for delaySeconds in retryDelays {
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                guard isCurrentSession(generation) else { return }
                guard let user = try? await AuthAPI.me() else { continue }
                guard isCurrentSession(generation) else { return }
                await applyCheckedSession(user)
                return
            }
            guard isCurrentSession(generation) else { return }
            // Failed check: keep a session that already signed in. Tokens stay either way.
            guard phase != .authenticated else { return }
            self.error = "Couldn't reach the server - check your connection and try again."
            phase = .unauthenticated
        }
    }

    private func applyCheckedSession(_ user: UserResponse) async {
        currentUser = user
        phase = user.username != nil ? .authenticated : .onboardingPending
        guard phase == .authenticated else { return }
        await UserActionCache.shared.bootstrap()
        guard let uid = KeychainManager.readString(key: "userId") else { return }
        Analytics.identify(userId: uid)
        try? await Purchases.shared.logIn(uid)
    }

    private func storeSession(accessToken: String, refreshToken: String, userId: String) {
        bumpSessionGeneration()
        KeychainManager.save(key: "accessToken", string: accessToken)
        KeychainManager.save(key: "refreshToken", string: refreshToken)
        KeychainManager.save(key: "userId", string: userId)
    }

    func signup(
        email: String,
        password: String,
        username: String,
        displayName: String?,
        phoneNumber: String? = nil
    ) async {
        isLoading = true
        error = nil

        do {
            let response = try await AuthAPI.signup(
                email: email,
                password: password,
                username: username,
                displayName: displayName,
                phoneNumber: phoneNumber
            )
            storeSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                userId: response.userId
            )
            // Explicitly mark as needing onboarding (genres + ratings)
            phase = .onboardingPending
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Apple Sign In for returning users. Returns `OAuthResponse` so the caller
    /// can check `isNewUser` and decide navigation.
    func loginWithApple(idToken: String, nonce: String, authorizationCode: String? = nil) async -> OAuthResponse? {
        isLoading = true
        error = nil

        do {
            let response = try await AuthAPI.oauth(
                provider: "apple",
                idToken: idToken,
                nonce: nonce,
                authorizationCode: authorizationCode
            )
            storeSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                userId: response.userId
            )

            if !response.isNewUser {
                await fetchCurrentUser()
                phase = .authenticated
                await UserActionCache.shared.bootstrap()
                Analytics.identify(userId: response.userId)
                try? await Purchases.shared.logIn(response.userId)
            }
            isLoading = false
            return response
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await AuthAPI.login(email: email, password: password)
            storeSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                userId: response.userId
            )
            await fetchCurrentUser()
            phase = .authenticated
            await UserActionCache.shared.bootstrap()
            if let user = currentUser {
                Analytics.identify(
                    userId: response.userId,
                    userProperties: ["username": user.username ?? "", "email": email]
                )
            }
            try? await Purchases.shared.logIn(response.userId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteAccount() async -> Bool {
        isLoading = true
        error = nil
        do {
            try await AuthAPI.deleteAccount()
            // Clear local state (same as logout)
            logout()
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func logout() {
        // Device token cleanup skipped on logout — backend handles stale
        // tokens automatically when APNs returns 410 on next push attempt.
        bumpSessionGeneration()
        KeychainManager.delete(key: "accessToken")
        KeychainManager.delete(key: "refreshToken")
        KeychainManager.delete(key: "userId")
        currentUser = nil
        error = nil
        isLoading = false
        phase = .unauthenticated
        UserActionCache.shared.reset()
        Analytics.reset()
        Purchases.shared.logOut { _, _ in }
    }

    func fetchCurrentUser() async {
        do {
            currentUser = try await AuthAPI.me()
        } catch {
            if case APIError.unauthorized = error {
                logout()
            }
        }
    }
}
