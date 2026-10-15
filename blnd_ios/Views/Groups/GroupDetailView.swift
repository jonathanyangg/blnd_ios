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
    @State var blendCurrentId: Int?
    @State var watchlistCurrentId: Int?
    @State var isLoading = true
    @State var loadError: UserFacingError?
    @State var showMembers = false
    @State var selectedTab: GroupTab = .blendPicks
    @State var viewMode: ViewMode = .reels
    @State var toastMessage: UserFacingError?
    @State var toastRetry: (() -> Void)?
    @State var toastTask: Task<Void, Never>?
    @State var isEditingName = false
    @State var editedName = ""
    @Namespace var tabNamespace
    @State var catalogFilters = CatalogFilterStore.shared
    @Environment(\.dismiss) var dismiss
    @Environment(TabState.self) var tabState

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
            } else if let error = loadError {
                Spacer()
                ErrorStateView(message: error) {
                    Task { await loadAll(forceRefresh: true) }
                }
                Spacer()
            } else if viewMode == .reels {
                reelsFeed
            } else {
                gridFeed
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackGesture()
        .task(id: catalogFilters.filter) {
            await loadAll(forceRefresh: group != nil)
        }
        .refreshable { await loadAll(forceRefresh: true) }
        .sheet(isPresented: $showMembers) {
            membersSheet
        }
        .overlay {
            if isEditingName {
                RenameOverlay(
                    title: "Rename Blend",
                    placeholder: "Blend name",
                    text: $editedName,
                    maxLength: 30,
                    onSave: { saveGroupName() },
                    onDismiss: { isEditingName = false }
                )
            }
        }
        .overlay(alignment: .top) {
            if let toast = toastMessage {
                ErrorToast(
                    message: toast,
                    retry: toastRetry,
                    onDismiss: { toastMessage = nil; toastRetry = nil }
                )
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .transition(
                    .move(edge: .top)
                        .combined(with: .opacity)
                )
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
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 6) {
                        groupNameRow(group)
                        memberAvatarStack(group)
                    }
                    .frame(maxWidth: 220)

                    Spacer(minLength: 8)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .reels ? .grid : .reels
                        }
                    } label: {
                        Image(
                            systemName: viewMode == .reels
                                ? "square.grid.2x2"
                                : "rectangle.stack"
                        )
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            groupTabPicker
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            HStack {
                CatalogFilterButton()
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Divider().overlay(AppTheme.border)
        }
        .background(AppTheme.background)
    }

    func memberAvatarStack(_ group: GroupDetailResponse) -> some View {
        Button {
            showMembers = true
        } label: {
            HStack(spacing: 0) {
                let visible = group.members.prefix(3)
                ForEach(Array(visible.enumerated()), id: \.offset) { index, member in
                    AvatarView(url: member.avatarUrl, size: 22, overlap: index > 0)
                }
                if group.members.count > 3 {
                    ZStack {
                        Circle()
                            .fill(AppTheme.card)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(AppTheme.background, lineWidth: 2)
                            )
                        Text("+\(group.members.count - 3)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, -8)
                }
            }
        }
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

    func groupNameRow(
        _ group: GroupDetailResponse
    ) -> some View {
        Button {
            editedName = group.name
            isEditingName = true
        } label: {
            HStack(spacing: 6) {
                Text(group.displayTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textDim)
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
