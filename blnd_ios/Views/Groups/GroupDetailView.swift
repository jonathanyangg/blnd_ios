import SwiftUI

struct GroupDetailView: View {
    let groupId: Int

    @State private var group: GroupDetailResponse?
    @State private var recommendations: [GroupRecMovieResponse] = []
    @State private var watchlist: [WatchlistMovieResponse] = []
    @State private var isLoading = true
    @State private var showAddMember = false
    @State private var addUsername = ""
    @State private var addError: String?
    @State private var isAdding = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 60)
            } else if let group {
                VStack(alignment: .leading, spacing: 0) {
                    groupHeader(group)
                    blendPicksSection
                    watchlistSection
                    membersSection(group)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .alert("Add Member", isPresented: $showAddMember) {
            TextField("Username", text: $addUsername)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {
                addUsername = ""
                addError = nil
            }
            Button("Add") {
                Task { await addMember() }
            }
        } message: {
            if let addError {
                Text(addError)
            } else {
                Text("Enter a username to add to this group.")
            }
        }
    }

    // MARK: - Header

    private func groupHeader(
        _ group: GroupDetailResponse
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(
                        Array(
                            group.members.prefix(3).enumerated()
                        ),
                        id: \.element.id
                    ) { index, _ in
                        AvatarView(size: 28, overlap: index > 0)
                    }

                    if group.members.count > 3 {
                        ZStack {
                            Circle()
                                .fill(AppTheme.card)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(
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
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Blend Picks

    @ViewBuilder
    private var blendPicksSection: some View {
        Text("Blend Picks")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.bottom, 4)

        Text("Recommended for your group")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
            .padding(.bottom, 12)

        if recommendations.isEmpty {
            Text("Rate more movies to get group picks")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
                .padding(.vertical, 20)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recommendations) { movie in
                        NavigationLink {
                            MovieDetailView(tmdbId: movie.tmdbId)
                        } label: {
                            MovieCard(
                                width: 90,
                                height: 130,
                                posterPath: movie.posterPath
                            )
                        }
                    }
                }
            }
        }

        Spacer().frame(height: 20)
    }

    // MARK: - Watchlist

    @ViewBuilder
    private var watchlistSection: some View {
        HStack {
            Text("Watchlist")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.bottom, 12)

        if watchlist.isEmpty {
            Text("No movies in the group watchlist yet")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
                .padding(.bottom, 20)
        } else {
            ForEach(watchlist) { item in
                NavigationLink {
                    MovieDetailView(tmdbId: item.tmdbId)
                } label: {
                    watchlistRow(item)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(AppTheme.cardSecondary)
            }
            .padding(.bottom, 8)
        }

        Spacer().frame(height: 12)
    }

    private func watchlistRow(
        _ item: WatchlistMovieResponse
    ) -> some View {
        HStack(spacing: 12) {
            MovieCard(
                width: 40,
                height: 56,
                posterPath: item.posterPath
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                if let addedBy = item.addedBy {
                    Text("added by \(addedBy)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textDim)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Members

    private func membersSection(
        _ group: GroupDetailResponse
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showAddMember = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }

            ForEach(group.members) { member in
                HStack(spacing: 12) {
                    AvatarView(size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            member.displayName ?? member.username
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        Text("@\(member.username)")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Spacer()
                    if member.id == group.createdBy {
                        Text("Owner")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textDim)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadAll() async {
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
            print("[GroupDetailView] Load failed: \(error)")
        }
        isLoading = false
    }

    private func addMember() async {
        let trimmed = addUsername.trimmingCharacters(
            in: .whitespaces
        )
        guard !trimmed.isEmpty else { return }
        isAdding = true

        do {
            group = try await GroupsAPI.addMember(
                groupId: groupId,
                username: trimmed
            )
            addUsername = ""
            addError = nil
            showAddMember = false
        } catch let APIError.badRequest(message) {
            addError = message
            showAddMember = true
        } catch {
            addError = error.localizedDescription
            showAddMember = true
        }

        isAdding = false
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(groupId: 1)
    }
}
