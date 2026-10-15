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
    var error: UserFacingError?
    var showPaywall = false
    /// Latest RevenueCat customer info. Nil until logIn, purchase, or restore refreshes it.
    private(set) var revenueCatCustomerInfo: CustomerInfo?

    /// Backend first (`is_premium`, then a paid tier that has not expired).
    /// RevenueCat's `premium` entitlement covers the gap before the webhook lands.
    var isPremium: Bool {
        Self.isPremium(
            serverFlag: currentUser?.isPremium ?? nil,
            tier: currentUser?.subscriptionTier,
            expiresAt: currentUser?.subscriptionExpiresAt,
            revenueCatActive: revenueCatEntitlementActive
        )
    }

    /// Paid `profiles.subscription_tier` values. The DB check allows only `free` and `premium`.
    static let paidTiers: Set<String> = ["premium"]
    /// RevenueCat entitlement attached to `blnd_premium_monthly`.
    static let premiumEntitlementID = "premium"

    /// True if the server flag is true, the paid tier is still open, or RevenueCat is active.
    static func isPremium(
        serverFlag: Bool?,
        tier: String?,
        expiresAt: String?,
        revenueCatActive: Bool,
        now: Date = Date()
    ) -> Bool {
        if serverFlag == true { return true }
        if paidTiers.contains(tier ?? ""), expiryIsOpen(expiresAt, now: now) { return true }
        return revenueCatActive
    }

    static func entitlementIsActive(_ activeIDs: Set<String>) -> Bool {
        activeIDs.contains(premiumEntitlementID)
    }

    private var revenueCatEntitlementActive: Bool {
        guard let info = revenueCatCustomerInfo else { return false }
        return Self.entitlementIsActive(Set(info.entitlements.active.keys))
    }

    private static func expiryIsOpen(_ raw: String?, now: Date) -> Bool {
        guard let raw, !raw.isEmpty else { return true }
        guard let expires = parseExpiry(raw) else { return true }
        return expires > now
    }

    /// Prod sends Python `isoformat()`, including microseconds and `+00:00`.
    private static func parseExpiry(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: raw) { return date }
        guard let fraction = raw.range(of: #"\.\d+"#, options: .regularExpression) else { return nil }
        var stripped = raw
        stripped.removeSubrange(fraction)
        return plain.date(from: stripped)
    }

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

        // Proactively refresh tokens before checking session.
        // 401 rejects the session. Anything else keeps the tokens and falls
        // through to /auth/me, which retries below.
        do {
            try await APIClient.shared.refreshTokens()
        } catch APIError.unauthorized {
            phase = .unauthenticated
            isCheckingSession = false
            return
        } catch {
            // 403, 500, 503, or a network error. Tokens stay in the Keychain.
        }

        do {
            let user = try await AuthAPI.me()
            currentUser = user
            phase = user.username != nil ? .authenticated : .onboardingPending
            if phase == .authenticated {
                await UserActionCache.shared.bootstrap()
                if let uid = KeychainManager.readString(key: "userId") {
                    Analytics.identify(userId: uid)
                    await logInRevenueCat(userId: uid)
                }
            }
        } catch APIError.unauthorized {
            // Tokens definitively rejected - real sign-out. (APIClient's
            // forceLogoutNotification also lands here when refresh fails.)
            phase = .unauthenticated
        } catch {
            // Transient failure (offline, cold backend, server 5xx). The
            // tokens are still in the Keychain - retry with backoff so a
            // waking server doesn't dump the user at the login screen.
            var lastError: Error = error
            for delaySeconds in [2.0, 5.0, 10.0] {
                try? await Task.sleep(
                    nanoseconds: UInt64(delaySeconds * 1_000_000_000)
                )
                do {
                    let user = try await AuthAPI.me()
                    currentUser = user
                    phase = user.username != nil ? .authenticated : .onboardingPending
                    if phase == .authenticated {
                        await UserActionCache.shared.bootstrap()
                        if let uid = KeychainManager.readString(key: "userId") {
                            Analytics.identify(userId: uid)
                            await logInRevenueCat(userId: uid)
                        }
                    }
                    isCheckingSession = false
                    return
                } catch {
                    lastError = error
                }
            }
            // Still failing: show sign-in, but tokens stay in the Keychain so
            // the next launch (or a successful retry) restores the session.
            self.error = UserFacingError.capture(lastError, screen: "CheckSession")
            phase = .unauthenticated
        }

        isCheckingSession = false
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
            KeychainManager.save(key: "accessToken", string: response.accessToken)
            KeychainManager.save(key: "refreshToken", string: response.refreshToken)
            KeychainManager.save(key: "userId", string: response.userId)
            // Explicitly mark as needing onboarding (genres + ratings)
            phase = .onboardingPending
        } catch {
            self.error = UserFacingError.capture(error, screen: "SignUp")
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
                await fetchCurrentUser()
                phase = .authenticated
                await UserActionCache.shared.bootstrap()
                Analytics.identify(userId: response.userId)
                await logInRevenueCat(userId: response.userId)
            }
            isLoading = false
            return response
        } catch {
            self.error = UserFacingError.capture(error, screen: "AppleLogin")
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
            await fetchCurrentUser()
            phase = .authenticated
            await UserActionCache.shared.bootstrap()
            if let user = currentUser {
                Analytics.identify(
                    userId: response.userId,
                    userProperties: ["username": user.username ?? "", "email": email]
                )
            }
            await logInRevenueCat(userId: response.userId)
        } catch {
            self.error = UserFacingError.capture(error, screen: "Login")
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
            self.error = UserFacingError.capture(error, screen: "DeleteAccount")
            isLoading = false
            return false
        }
    }

    func logout() {
        // Device token cleanup skipped on logout — backend handles stale
        // tokens automatically when APNs returns 410 on next push attempt.
        KeychainManager.delete(key: "accessToken")
        KeychainManager.delete(key: "refreshToken")
        KeychainManager.delete(key: "userId")
        currentUser = nil
        revenueCatCustomerInfo = nil
        error = nil
        isLoading = false
        phase = .unauthenticated
        UserActionCache.shared.reset()
        Analytics.reset()
        Purchases.shared.logOut { _, _ in }
    }

    /// Identifies the user, then refreshes customer info so the entitlement is current.
    func logInRevenueCat(userId: String) async {
        let loggedIn = try? await Purchases.shared.logIn(userId)
        await refreshRevenueCatCustomerInfo(fallingBackTo: loggedIn?.customerInfo)
    }

    /// Network refresh of customer info. `fallingBackTo` is the info just returned by
    /// logIn, purchase, or restore. An in-hand active entitlement wins so a lagging
    /// refetch cannot hide a purchase that just completed.
    func refreshRevenueCatCustomerInfo(fallingBackTo info: CustomerInfo? = nil) async {
        let fresh = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
        if let info, Self.entitlementIsActive(Set(info.entitlements.active.keys)) {
            revenueCatCustomerInfo = info
        } else if let fresh {
            revenueCatCustomerInfo = fresh
        } else if let info {
            revenueCatCustomerInfo = info
        }
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
