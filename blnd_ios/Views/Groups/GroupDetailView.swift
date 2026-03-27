import SwiftUI

enum GroupTab: String, CaseIterable {
    case blendPicks = "Blend Picks"
    case watchlist = "Watchlist"
}

struct GroupDetailView: View {
    let groupId: Int

    @State var group: GroupDetailResponse?
    @State var recommendations: [GroupRecMovieResponse] = []
    @State var groupReelMovies: [ReelMovie] = []
    @State var seenRecIds: Set<Int> = []
    @State var isLoadingMoreRecs = false
    @State var watchlist: [WatchlistMovieResponse] = []
    @State var isLoading = true
    @State var showMembers = false
    @State var selectedTab: GroupTab = .blendPicks
    @State var viewMode: ViewMode = .reels
    @State var toastMessage: String?
    @Namespace var tabNamespace
    @Environment(\.dismiss) var dismiss

    var groupContext: ReelCardView.GroupContext? {
        guard let group else { return nil }
        return .init(
            groupId: groupId, groupName: group.name
        )
    }

    var currentUserId: String {
        KeychainManager.readString(key: "userId") ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isLoading, group != nil {
                groupHeader
            }

            if isLoading {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if viewMode == .reels {
                reelsFeed
            } else {
                gridFeed
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
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
                        size: 13, weight: .medium
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
                    .onTapGesture {
                        toastMessage = nil
                    }
            }
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: toastMessage
        )
    }

    // MARK: - Shared Header

    var groupHeader: some View {
        VStack(spacing: 0) {
            if let group {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.system(
                                size: 18, weight: .bold
                            ))
                            .foregroundStyle(.white)

                        Button {
                            showMembers = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(
                                    "\(group.members.count) members"
                                )
                                .font(.system(size: 12))
                                .foregroundStyle(
                                    AppTheme.textMuted
                                )
                                Image(
                                    systemName: "chevron.right"
                                )
                                .font(.system(
                                    size: 9, weight: .medium
                                ))
                                .foregroundStyle(
                                    AppTheme.textDim
                                )
                            }
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(
                            .easeInOut(duration: 0.2)
                        ) {
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
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

            groupTabPicker
                .padding(.horizontal, 24)
                .padding(.bottom, 4)

            Divider().overlay(AppTheme.border)
        }
        .background(AppTheme.background)
    }

    var groupTabPicker: some View {
        HStack(spacing: 24) {
            ForEach(GroupTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(
                        .easeInOut(duration: 0.2)
                    ) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(
                                size: 14,
                                weight: selectedTab == tab
                                    ? .bold : .medium
                            ))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? .white
                                    : AppTheme.textMuted
                            )

                        Rectangle()
                            .fill(
                                selectedTab == tab
                                    ? .white : .clear
                            )
                            .frame(height: 2)
                    }
                }
            }
        }
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
