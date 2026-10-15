@testable import blnd_ios
import Foundation
import Testing

struct UserFacingErrorTests {
    @Test func offlineAndTimeoutStaySeparate() {
        let offline = UserFacingError.map(URLError(.notConnectedToInternet))
        let wrapped = UserFacingError.map(
            APIError.networkError(URLError(.timedOut))
        )

        #expect(offline.category == .offline)
        #expect(offline.message == "Check your connection and try again.")
        #expect(wrapped.category == .timeout)
        #expect(wrapped.title == "Request timed out")
    }

    @Test func envelopeAndLegacyValidationUseTheSameCopy() {
        let envelope = Data("""
        {"error":{"code":"VALIDATION_ERROR","message":"body.username: Username is already taken","request_id":"x"},"detail":"SECRET_BODY"}
        """.utf8)
        let legacy = Data("""
        {"detail":"Username is already taken"}
        """.utf8)

        let fromCode = UserFacingError.map(APIError.decode(status: 422, data: envelope))
        let fromDetail = UserFacingError.map(APIError.decode(status: 400, data: legacy))

        #expect(fromCode.fields["username"] == "That username is taken.")
        #expect(fromDetail.fields["username"] == "That username is taken.")
        #expect(!fromCode.message.contains("SECRET"))
        #expect(fromCode.field == "username")
    }

    @Test func validationSummaryMapsEachKnownField() {
        let body = Data("""
        {"error":{"code":"VALIDATION_ERROR","message":"body.password: Password must be at least 8 characters; body.username: Username must be 3-30 characters","request_id":"live"},"detail":"body.password: Password must be at least 8 characters; body.username: Username must be 3-30 characters"}
        """.utf8)
        let copy = UserFacingError.map(APIError.decode(status: 422, data: body))

        #expect(copy.fields["password"] == "Use at least 8 characters.")
        #expect(copy.fields["username"] == "Usernames are 3–30 characters.")
        #expect(copy.inline(for: "password")?.message == "Use at least 8 characters.")
    }

    @Test func premiumCodeOpensThePaywall() {
        let body = Data("""
        {"error":{"code":"PREMIUM_REQUIRED","message":"Upgrade to blnd+ SECRET","request_id":"x"},"detail":"Upgrade to blnd+ SECRET"}
        """.utf8)
        let error = APIError.decode(status: 402, data: body)
        let copy = UserFacingError.map(error)

        #expect(error.opensPaywall)
        #expect(copy.opensPaywall)
        #expect(copy.message == "Upgrade to blnd+ to do this.")
        #expect(!copy.message.contains("SECRET"))
    }

    @Test func freeGroupCapAndLegacyUpgradeOpenThePaywall() {
        let coded = Data("""
        {"error":{"code":"FREE_GROUP_CAP","message":"Free groups are limited to 8 members.","request_id":"x"},"detail":"Free groups are limited to 8 members."}
        """.utf8)
        let legacy = Data("""
        {"detail":{"code":"free_group_cap","message":"Upgrade to blnd+ for groups up to 20."}}
        """.utf8)

        #expect(APIError.decode(status: 402, data: coded).opensPaywall)
        #expect(APIError.decode(status: 402, data: legacy).opensPaywall)
        #expect(!UserFacingError.map(APIError.decode(status: 402, data: legacy)).message.contains("20"))
    }

    @Test func unknownServerTextStaysGeneric() {
        let leaked = "Username already taken SECRET_BODY"
        let envelope = Data("""
        {"error":{"code":"BAD_REQUEST","message":"\(leaked)","request_id":"x"},"detail":"\(leaked)"}
        """.utf8)
        let copy = UserFacingError.map(APIError.decode(status: 400, data: envelope))
        let legacy = UserFacingError.map(
            APIError.badRequest(APIFieldError(code: nil, issues: [APIIssue(field: nil, text: leaked)], raw: leaked, opensPaywall: false))
        )

        for item in [copy, legacy] {
            #expect(item.category == .validation)
            #expect(item.fields.isEmpty)
            #expect(!item.message.contains("SECRET_BODY"))
            #expect(!item.message.contains("Username"))
        }
        #expect(UserFacingError.diagnostic(APIError.decode(status: 400, data: envelope)).contains("SECRET_BODY"))
    }
}
