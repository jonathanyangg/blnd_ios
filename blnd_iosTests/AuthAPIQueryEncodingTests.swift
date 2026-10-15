@testable import blnd_ios
import Testing

struct AuthAPIQueryEncodingTests {
    @Test func encodesQueryDelimiters() {
        #expect(AuthAPI.encodedSearchQuery("a&x=1") == "a%26x%3D1")
        #expect(AuthAPI.encodedSearchQuery("1+1") == "1%2B1")
        #expect(AuthAPI.encodedSearchQuery("a#b") == "a%23b")
    }
}
