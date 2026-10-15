@testable import blnd_ios
import Foundation
import Testing

struct PremiumGateTests {
    @Test func missingIsPremiumWithPaidUnexpiredTier() throws {
        let future = try decode(
            """
            {
              "id": "user-1",
              "favorite_genres": [],
              "subscription_tier": "premium",
              "subscription_expires_at": "2099-01-01T00:00:00.000000+00:00"
            }
            """
        )
        #expect(future.isPremium == nil)
        #expect(future.subscriptionTier == "premium")
        #expect(future.subscriptionExpiresAt == "2099-01-01T00:00:00.000000+00:00")
        #expect(gate(future, revenueCatActive: false))

        let openEnded = try decode(
            """
            {
              "id": "user-1",
              "favorite_genres": [],
              "subscription_tier": "premium",
              "subscription_expires_at": null
            }
            """
        )
        #expect(openEnded.isPremium == nil)
        #expect(openEnded.subscriptionExpiresAt == nil)
        #expect(gate(openEnded, revenueCatActive: false))
    }

    @Test func expiredPaidTierIsNotPremium() throws {
        let user = try decode(
            """
            {
              "id": "user-1",
              "favorite_genres": [],
              "subscription_tier": "premium",
              "subscription_expires_at": "2000-01-01T00:00:00.000000+00:00"
            }
            """
        )
        #expect(user.isPremium == nil)
        #expect(!gate(user, revenueCatActive: false))
    }

    @Test func freeTierIsNotPremium() throws {
        let user = try decode(
            """
            {
              "id": "user-1",
              "favorite_genres": [],
              "subscription_tier": "free",
              "subscription_expires_at": "2099-01-01T00:00:00Z"
            }
            """
        )
        #expect(user.subscriptionTier == "free")
        #expect(!gate(user, revenueCatActive: false))
    }

    @Test func serverIsPremiumTrue() throws {
        let user = try decode(
            """
            {
              "id": "user-1",
              "favorite_genres": [],
              "is_premium": true,
              "subscription_tier": "free"
            }
            """
        )
        #expect(user.isPremium == true)
        #expect(gate(user, revenueCatActive: false))
    }

    @Test func revenueCatPremiumEntitlementUnlocksFreeServerUser() throws {
        let user = try decode(
            """
            {
              "id": "user-1",
              "favorite_genres": []
            }
            """
        )
        #expect(user.isPremium == nil)
        #expect(user.subscriptionTier == nil)
        #expect(user.subscriptionExpiresAt == nil)
        #expect(AuthState.entitlementIsActive(["premium"]))
        #expect(!AuthState.entitlementIsActive(["plus"]))
        #expect(gate(user, revenueCatActive: AuthState.entitlementIsActive(["premium"])))
        #expect(!gate(user, revenueCatActive: AuthState.entitlementIsActive(["plus"])))
    }

    private func decode(_ json: String) throws -> UserResponse {
        try JSONDecoder().decode(UserResponse.self, from: Data(json.utf8))
    }

    private func gate(_ user: UserResponse, revenueCatActive: Bool) -> Bool {
        AuthState.isPremium(
            serverFlag: user.isPremium,
            tier: user.subscriptionTier,
            expiresAt: user.subscriptionExpiresAt,
            revenueCatActive: revenueCatActive
        )
    }
}
