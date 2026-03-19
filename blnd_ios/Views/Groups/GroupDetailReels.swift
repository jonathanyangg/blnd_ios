import SwiftUI

// MARK: - Reels Mode

extension GroupDetailView {
    var reelsContent: some View {
        ZStack(alignment: .top) {
            switch selectedTab {
            case .blendPicks:
                if recommendations.isEmpty {
                    emptyState(
                        "Rate more movies to get group picks"
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
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
                    emptyState(
                        "No movies in the group watchlist yet"
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                } else {
                    ReelsFeedView(
                        movies: watchlist.map {
                            ReelMovie(from: $0)
                        },
                        groupContext: groupContext
                    )
                }
            }

            reelsHeader
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
                        .shadow(radius: 4)
                        .padding(.top, 8)

                    Button { showMembers = true } label: {
                        HStack(spacing: 6) {
                            Text(
                                "\(group.members.count) members"
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(
                                .white.opacity(0.7)
                            )
                            Image(
                                systemName: "chevron.right"
                            )
                            .font(.system(
                                size: 9,
                                weight: .medium
                            ))
                            .foregroundStyle(
                                .white.opacity(0.5)
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
                                        : .white.opacity(0.6)
                                )
                                .shadow(radius: 2)

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
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    .black.opacity(0.6),
                    .black.opacity(0.3),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
