import Foundation

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

    /// Resolve auth phase on cold launch by checking the user's profile via GET /auth/me.
    /// If tokens exist but the user has no username, they need onboarding.
    func checkSession() async {
        guard KeychainManager.readString(key: "accessToken") != nil else {
            phase = .unauthenticated
            isCheckingSession = false
            return
        }

        do {
            let user = try await AuthAPI.me()
            currentUser = user
            phase = user.username != nil ? .authenticated : .onboardingPending
            if phase == .authenticated {
                await UserActionCache.shared.bootstrap()
            }
        } catch {
            // Token invalid/expired — APIClient retry + forceLogoutNotification
            // handles refresh failures, so just mark unauthenticated
            phase = .unauthenticated
        }

        isCheckingSession = false
    }

    func signup(email: String, password: String, username: String, displayName: String?) async {
        isLoading = true
        error = nil

        do {
            let response = try await AuthAPI.signup(
                email: email,
                password: password,
                username: username,
                displayName: displayName
            )
            KeychainManager.save(key: "accessToken", string: response.accessToken)
            KeychainManager.save(key: "refreshToken", string: response.refreshToken)
            KeychainManager.save(key: "userId", string: response.userId)
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
            KeychainManager.save(key: "accessToken", string: response.accessToken)
            KeychainManager.save(key: "refreshToken", string: response.refreshToken)
            KeychainManager.save(key: "userId", string: response.userId)

            if !response.isNewUser {
                phase = .authenticated
                await UserActionCache.shared.bootstrap()
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
            KeychainManager.save(key: "accessToken", string: response.accessToken)
            KeychainManager.save(key: "refreshToken", string: response.refreshToken)
            KeychainManager.save(key: "userId", string: response.userId)
            phase = .authenticated
            await UserActionCache.shared.bootstrap()
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
        KeychainManager.delete(key: "accessToken")
        KeychainManager.delete(key: "refreshToken")
        KeychainManager.delete(key: "userId")
        currentUser = nil
        phase = .unauthenticated
        UserActionCache.shared.reset()
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
