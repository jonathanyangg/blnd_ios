@testable import blnd_ios
import Foundation
import Testing

struct GateErrorTests {
    @Test func premiumRequiredBothShapes() {
        let message = "blnd+ is required"
        let current = map(
            status: 402,
            json: """
            {"error":{"code":"PREMIUM_REQUIRED","message":"\(message)","request_id":"r1"},"detail":"\(message)"}
            """
        )
        expectPaywall(current, code: "PREMIUM_REQUIRED", message: message)

        let legacy = map(
            status: 403,
            json: """
            {"detail":{"code":"PREMIUM_REQUIRED","message":"\(message)"}}
            """
        )
        expectPaywall(legacy, code: "PREMIUM_REQUIRED", message: message)
    }

    @Test func freeGroupCapBothShapes() {
        let message = "Free groups are limited to 4 members. Upgrade to blnd+ for groups up to 12."
        let current = map(
            status: 402,
            json: """
            {"error":{"code":"FREE_GROUP_CAP","message":"\(message)"},"detail":"\(message)"}
            """
        )
        expectPaywall(current, code: "FREE_GROUP_CAP", message: message)

        let legacy = map(
            status: 402,
            json: """
            {"detail":{"code":"free_group_cap","cap":4,"message":"\(message)"}}
            """
        )
        expectPaywall(legacy, code: "free_group_cap", message: message)
    }

    @Test func groupFullShowsMessageAndSkipsPaywall() {
        let message = "Group is full (12 members max)."
        let current = map(
            status: 402,
            json: """
            {"error":{"code":"GROUP_FULL","message":"\(message)"},"detail":"\(message)"}
            """
        )
        expectMessage(current, code: "GROUP_FULL", message: message)

        let legacy = map(
            status: 400,
            json: """
            {"detail":{"code":"group_full","cap":12,"message":"\(message)"}}
            """
        )
        expectMessage(legacy, code: "group_full", message: message)
    }

    @Test func legacyStringDetailAndGarbageBody() {
        let taken = map(status: 400, json: #"{"detail":"Username already taken"}"#)
        expectMessage(taken, code: nil, message: "Username already taken")

        let upgrade = map(
            status: 400,
            json: #"{"detail":"Upgrade to blnd+ for groups up to 12."}"#
        )
        #expect(upgrade.opensPaywall)
        #expect(upgrade.localizedDescription == "Upgrade to blnd+ for groups up to 12.")

        let partial = map(status: 402, json: #"{"detail":{"code":"FREE_GROUP_CAP"}}"#)
        expectPaywall(partial, code: "FREE_GROUP_CAP", message: "Request failed")

        let garbage = APIClient.shared.mapError(status: 402, data: Data("not-json".utf8))
        expectMessage(garbage, code: nil, message: "Request failed")

        let empty = APIClient.shared.mapError(status: 402, data: Data())
        expectMessage(empty, code: nil, message: "Request failed")
    }

    private func map(status: Int, json: String) -> APIError {
        APIClient.shared.mapError(status: status, data: Data(json.utf8))
    }

    private func expectPaywall(_ error: APIError, code: String, message: String) {
        guard case let .badRequest(parsed, parsedCode) = error else {
            Issue.record("expected badRequest, got \(error)")
            return
        }
        #expect(parsed == message)
        #expect(parsedCode == code)
        #expect(error.opensPaywall)
        #expect(error.localizedDescription == message)
    }

    private func expectMessage(_ error: APIError, code: String?, message: String) {
        guard case let .badRequest(parsed, parsedCode) = error else {
            Issue.record("expected badRequest, got \(error)")
            return
        }
        #expect(parsed == message)
        #expect(parsedCode == code)
        #expect(!error.opensPaywall)
        #expect(error.localizedDescription == message)
    }
}
