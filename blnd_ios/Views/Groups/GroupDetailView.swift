import SwiftUI

private enum GroupTab: String, CaseIterable {
    case blendPicks = "Blend Picks"
    case watchlist = "Watchlist"
}

struct GroupDetailView: View {
    let groupId: Int

    @State private var group: GroupDetailResponse?
    @State private var recommendations: [GroupRecMovieResponse] = []
    @State private var watchlist: [WatchlistMovieResponse] = []
    @State private var isLoading = true
    @State private var showMembers = false
    @State private var showEditName = false
    @State private var editName = ""
    @State private var selectedTab: GroupTab = .blendPicks
    @State private var toastMessage: String?
    @Namespace private var tabNamespace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
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
                        .font(.system(size: 13, weight: .medium))
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
            .alert("Rename Group", isPresented: $showEditName) {
                TextField("Group name", text: $editName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { Task { await saveGroupName() } }
            }
    }

    private var content: some View {
        GeometryReader { geo in
            ScrollView {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let group {
                    VStack(spacing: 0) {
                        groupHeader(group)
                        tabPicker
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                        let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
                        let cardHeight = cardWidth * 1.5

                        switch selectedTab {
                        case .blendPicks:
                            blendPicksGrid(
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                        case .watchlist:
                            watchlistGrid(
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }

    // MARK: - Header

    private func groupHeader(
        _ group: GroupDetailResponse
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(group.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Button {
                    editName = group.name
                    showEditName = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Button { showMembers = true } label: {
                memberAvatarsRow(group)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
    }

    private func memberAvatarsRow(
        _ group: GroupDetailResponse
    ) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(
                    Array(group.members.prefix(3).enumerated()),
                    id: \.element.id
                ) { index, member in
                    AvatarView(url: member.avatarUrl, size: 28, overlap: index > 0)
                }
                if group.members.count > 3 {
                    ZStack {
                        Circle()
                            .fill(AppTheme.card)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(
                                        AppTheme.background,
                                        lineWidth: 2
                                    )
                            )
                        Text("+\(group.members.count - 3)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, -10)
                }
            }
            Text("\(group.members.count) members")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textDim)
        }
        .padding(.bottom, 20)
    }

    private var currentUserId: String {
        KeychainManager.readString(key: "userId") ?? ""
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 24) {
            ForEach(GroupTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(
                                size: 15,
                                weight: selectedTab == tab
                                    ? .bold : .medium
                            ))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? .white : AppTheme.textMuted
                            )

                        if selectedTab == tab {
                            Rectangle()
                                .fill(.white)
                                .frame(height: 2)
                                .matchedGeometryEffect(
                                    id: "groupUnderline",
                                    in: tabNamespace
                                )
                        } else {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Blend Picks Grid

    private func blendPicksGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if recommendations.isEmpty {
                emptyState("Rate more movies to get group picks")
            } else {
                movieGrid {
                    ForEach(recommendations) { movie in
                        NavigationLink {
                            MovieDetailView(
                                tmdbId: movie.tmdbId,
                                title: movie.title
                            )
                        } label: {
                            MovieCard(
                                title: movie.title,
                                year: movie.yearString,
                                posterPath: movie.posterPath,
                                width: cardWidth,
                                height: cardHeight,
                                scorePercent: movie.scorePercent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Watchlist Grid

    private func watchlistGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if watchlist.isEmpty {
                emptyState("No movies in the group watchlist yet")
            } else {
                movieGrid {
                    ForEach(watchlist) { item in
                        NavigationLink {
                            MovieDetailView(tmdbId: item.tmdbId)
                        } label: {
                            MovieCard(
                                title: item.title,
                                posterPath: item.posterPath,
                                width: cardWidth,
                                height: cardHeight,
                                scorePercent: item.matchPercent
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Shared

    private func movieGrid(
        @ViewBuilder content: () -> some View
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            content()
        }
        .padding(.horizontal, 24)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }

    // MARK: - Members Sheet

    private var membersSheet: some View {
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

// MARK: - Data Loading

extension GroupDetailView {
    func loadAll(forceRefresh: Bool = false) async {
        guard forceRefresh || group == nil else { return }
        do {
            async let groupResult = GroupsAPI.getGroup(
                groupId: groupId
            )
            async let recsResult = GroupsAPI.getRecommendations(
                groupId: groupId
            )
            async let watchlistResult = GroupsAPI.getWatchlist(
                groupId: groupId
            )

            let (groupData, recsData, watchlistData) = try await (
                groupResult, recsResult, watchlistResult
            )
            group = groupData
            recommendations = recsData.results
            watchlist = watchlistData.results
        } catch {
            if case APIError.rateLimited = error {
                showToast(
                    "Woah, slow down! Try again in a minute"
                )
            } else if group == nil {
                print("[GroupDetailView] Load failed: \(error)")
            } else {
                showToast(error.localizedDescription)
            }
        }
        isLoading = false
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            toastMessage = nil
        }
    }

    func saveGroupName() async {
        let trimmed = editName.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else { return }
        do {
            group = try await GroupsAPI.updateGroup(
                groupId: groupId,
                name: trimmed
            )
        } catch {
            print("[GroupDetailView] Rename failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(groupId: 1)
    }
}
