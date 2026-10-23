import Foundation
import Testing
@testable import blnd_ios

/// App Store Connect has closed the 2.0 train and already used versions up to 7 (last submissions were 6 and 7),
/// so the marketing version must be a higher integer. Release notes still call this release "2.0".
struct ReleaseVersionTests {
    @Test func marketingVersionIsAboveEveryClosedTrain() throws {
        let version = try #require(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        let major = try #require(Int(version), "marketing version \(version) must be a plain integer like the shipped 5/6/7")
        #expect(major >= 8)
    }

    @Test func buildNumberIsAtLeastTheLastUploadedBuild() throws {
        let build = try #require(Bundle.main.infoDictionary?["CFBundleVersion"] as? String)
        #expect((Int(build) ?? 0) >= 1000)
    }
}
