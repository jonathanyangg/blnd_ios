import Foundation

@Observable
class AuthState {
    var isAuthenticated = false
    var currentUser: UserResponse?
    var isLoading = false
    var error: String?

    private var logoutObserver: NSObjectProtocol?

    init() {
        isAuthenticated =
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
            // Don't set isAuthenticated here — onboarding still needs to complete
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await AuthAPI.login(email: email, password: password)
            KeychainManager.save(key: "accessToken", string: response.accessToken)
            KeychainManager.save(key: "refreshToken", string: response.refreshToken)
            KeychainManager.save(key: "userId", string: response.userId)
            isAuthenticated = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        KeychainManager.delete(key: "accessToken")
        KeychainManager.delete(key: "refreshToken")
        KeychainManager.delete(key: "userId")
        currentUser = nil
        isAuthenticated = false
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
