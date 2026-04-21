import Foundation

/// Mutation layer over GroupsAPI. Every method wraps a write endpoint and
/// invalidates UserActionCache so stale reads can't linger.
/// Read-only endpoints and watchlist mutations (which don't touch the
/// groups cache) stay on GroupsAPI.
enum GroupsService {
    static func createGroup(name: String) async throws -> GroupDetailResponse {
        let result: GroupDetailResponse = try await APIClient.shared.request(
            endpoint: "/groups/",
            method: "POST",
            body: CreateGroupRequest(name: name),
            authenticated: true
        )
        await invalidate()
        return result
    }

    static func updateGroup(
        groupId: Int,
        name: String
    ) async throws -> GroupDetailResponse {
        let result: GroupDetailResponse = try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)",
            method: "PATCH",
            body: UpdateGroupRequest(name: name),
            authenticated: true
        )
        await invalidate()
        return result
    }

    static func deleteGroup(groupId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/groups/\(groupId)",
            method: "DELETE",
            authenticated: true
        )
        await invalidate()
    }

    static func addMember(
        groupId: Int,
        username: String
    ) async throws -> GroupDetailResponse {
        let result: GroupDetailResponse = try await APIClient.shared.request(
            endpoint: "/groups/\(groupId)/members",
            method: "POST",
            body: AddMemberRequest(username: username),
            authenticated: true
        )
        await invalidate()
        return result
    }

    static func kickMember(
        groupId: Int,
        userId: String
    ) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/groups/\(groupId)/members/\(userId)/kick",
            method: "POST",
            authenticated: true
        )
        await invalidate()
    }

    static func leaveGroup(groupId: Int) async throws {
        try await APIClient.shared.requestVoid(
            endpoint: "/groups/\(groupId)/leave",
            method: "POST",
            authenticated: true
        )
        await invalidate()
    }

    @MainActor
    private static func invalidate() {
        UserActionCache.shared.invalidateGroups()
    }
}
