@testable import blnd_ios
import Testing

struct BlndIOSTests {
    @Test func example() {}

    @Test func resolvesReleaseAPIBaseURL() {
        let url = APIConfig.resolvedBaseURL(["API_BASE_URL": "https://blnd-backend.onrender.com"])
        #expect(url == "https://blnd-backend.onrender.com")
    }

    @Test func resolvesDebugLANAPIBaseURL() {
        let url = APIConfig.resolvedBaseURL(["API_BASE_URL": " http://192.168.7.121:8000 "])
        #expect(url == "http://192.168.7.121:8000")
    }
}
