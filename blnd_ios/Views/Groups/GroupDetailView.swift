import SwiftUI

enum GroupTab: String, CaseIterable {
    case blendPicks = "Blend Picks"
    case watchlist = "Watchlist"
}

struct GroupDetailView: View {
    let groupId: Int

    @State var group: GroupDetailResponse?
    @State var recommendations: [GroupRecMovieResponse] = []
    @State var seenRecIds: Set<Int> = []
    @State var isLoadingMoreRecs = false
    @State var watchlist: [WatchlistMovieResponse] = []
    @State var isLoading = true
    @State var showMembers = false
    @State var isEditingName = false
    @State var editName = ""
    @FocusState var nameFieldFocused: Bool
    @State var selectedTab: GroupTab = .blendPicks
    @State var viewMode: ViewMode = .reels
    @State var toastMessage: String?
    @Namespace var tabNamespace
    @Environment(\.dismiss) var dismiss

    var groupContext: ReelCardView.GroupContext? {
        guard let group else { return nil }
        return .init(groupId: groupId, groupName: group.name)
    }

    var currentUserId: String {
        KeychainManager.readString(key: "userId") ?? ""
    }

    var body: some View {
        Group {
            if viewMode == .reels, !isLoading, group != nil {
                reelsContent
            } else {
                gridContent
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = viewMode == .reels
                            ? .grid : .reels
                    }
                } label: {
                    Image(
                        systemName: viewMode == .reels
                            ? "square.grid.2x2"
                            : "rectangle.stack"
                    )
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            withAnimation(.easeInOut(duration: 0.2)) {
                viewMode = newTab == .watchlist ? .grid : .reels
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll(forceRefresh: true) }
        .sheet(isPresented: $showMembers) {
            membersSheet
        }
        .overlay(alignment: .top) {
            if let toast = toastMessage {
                Text(toast)
                    .font(.system(
                        size: 13,
                        weight: .medium
                    ))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                    )
                    .onTapGesture { toastMessage = nil }
            }
        }
        .animation(
            .easeInOut(duration: 0.3), value: toastMessage
        )
    }

    var membersSheet: some View {
        GroupMembersSheet(
            groupId: groupId,
            group: $group,
            isOwner: group?.createdBy == currentUserId,
            onGroupDeleted: { dismiss() }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppTheme.background)
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(groupId: 1)
    }
}
