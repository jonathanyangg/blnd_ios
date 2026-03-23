import SwiftUI

// MARK: - Reels Mode

extension GroupDetailView {
    var reelsContent: some View {
        VStack(spacing: 0) {
            reelsHeader
            reelsFeedContent
        }
    }

    @ViewBuilder
    private var reelsFeedContent: some View {
        switch selectedTab {
        case .blendPicks:
            if recommendations.isEmpty {
                Spacer()
                emptyState(
                    "Rate more movies to get group picks"
                )
                Spacer()
            } else {
                ReelsFeedView(
                    movies: recommendations.map {
                        ReelMovie(from: $0)
                    },
                    groupContext: groupContext
                )
            }
        case .watchlist:
            if watchlist.isEmpty {
                Spacer()
                emptyState(
                    "No movies in the group watchlist yet"
                )
                Spacer()
            } else {
                ReelsFeedView(
                    movies: watchlist.map {
                        ReelMovie(from: $0)
                    },
                    groupContext: groupContext
                )
            }
        }
    }

    var reelsHeader: some View {
        VStack(spacing: 0) {
            if let group {
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.name)
                        .font(.system(
                            size: 18,
                            weight: .bold
                        ))
                        .foregroundStyle(.white)

                    Button { showMembers = true } label: {
                        HStack(spacing: 6) {
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
                                size: 9,
                                weight: .medium
                            ))
                            .foregroundStyle(
                                AppTheme.textDim
                            )
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

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
            .padding(.horizontal, 24)

            Divider().overlay(AppTheme.border)
        }
        .background(AppTheme.background)
    }
}
