@testable import blnd_ios
import Testing

struct BlendDisplayNameTests {
    @Test func namedBlendKeepsItsName() {
        let title = BlendDisplayName.title(
            storedName: "Friday",
            memberNames: ["Alex Morgan", "Sam"]
        )
        #expect(title == "Friday")
    }

    @Test func blankNameUsesFirstNames() {
        #expect(
            BlendDisplayName.title(storedName: "  ", memberNames: ["Alex Morgan"])
                == "Alex"
        )
        #expect(
            BlendDisplayName.title(storedName: "", memberNames: ["Alex", "Sam Rivera"])
                == "Alex & Sam"
        )
        #expect(
            BlendDisplayName.title(
                storedName: "",
                memberNames: ["Alex", "Sam", "Jo Kim"]
            ) == "Alex, Sam & Jo"
        )
        #expect(
            BlendDisplayName.title(
                storedName: "",
                memberNames: ["Alex", "Sam", "Jo", "Riley", "Casey"]
            ) == "Alex, Sam +3"
        )
    }

    @Test func noMembersFallsBackToBlend() {
        #expect(BlendDisplayName.title(storedName: "", memberNames: ["  ", ""]) == "Blend")
    }

    @Test func blankDisplayNameUsesUsername() {
        let member = GroupMemberResponse(
            id: "1",
            username: "sam",
            displayName: "  ",
            avatarUrl: nil
        )
        #expect(member.blendNameSource == "sam")
    }
}
