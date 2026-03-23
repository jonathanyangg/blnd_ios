import SwiftUI

// MARK: - Grid Mode

extension GroupDetailView {
    var gridContent: some View {
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
                        gridTabPicker
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                        let cardWidth =
                            (geo.size.width - 24 * 2 - 12) / 2
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

    func groupHeader(
        _ group: GroupDetailResponse
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            nameRow(group)
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

    func nameRow(
        _ group: GroupDetailResponse
    ) -> some View {
        HStack(alignment: .center) {
            if isEditingName {
                TextField("Group name", text: $editName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .focused($nameFieldFocused)
                    .onSubmit { submitRename() }
                Button { submitRename() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(
                            size: 14,
                            weight: .bold
                        ))
                        .foregroundStyle(.white)
                }
                Button { isEditingName = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(
                            size: 14,
                            weight: .bold
                        ))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else {
                Text(group.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Button {
                    editName = group.name
                    isEditingName = true
                    nameFieldFocused = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            Spacer()
        }
    }

    func memberAvatarsRow(
        _ group: GroupDetailResponse
    ) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(
                    Array(
                        group.members.prefix(3).enumerated()
                    ),
                    id: \.element.id
                ) { index, member in
                    AvatarView(
                        url: member.avatarUrl,
                        size: 28,
                        overlap: index > 0
                    )
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

    // MARK: - Tab Picker

    var gridTabPicker: some View {
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
                                    ? .white
                                    : AppTheme.textMuted
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

    func blendPicksGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if recommendations.isEmpty {
                emptyState(
                    "Rate more movies to get group picks"
                )
            } else {
                movieGrid {
                    ForEach(
                        Array(recommendations.enumerated()),
                        id: \.element.id
                    ) { index, movie in
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
                        .onAppear {
                            if index >= recommendations.count - 4 {
                                Task { await loadMoreRecs() }
                            }
                        }
                    }

                    if isLoadingMoreRecs {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    // MARK: - Watchlist Grid

    func watchlistGrid(
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        Group {
            if watchlist.isEmpty {
                emptyState(
                    "No movies in the group watchlist yet"
                )
            } else {
                movieGrid {
                    ForEach(watchlist) { item in
                        NavigationLink {
                            MovieDetailView(
                                tmdbId: item.tmdbId
                            )
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

    func movieGrid(
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

    func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
    }
}
