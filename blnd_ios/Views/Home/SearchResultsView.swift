import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState
    @FocusState private var isFieldFocused: Bool

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var results: [MovieResponse] = []
    @State private var actorResults: [PersonResult] = []
    @State private var userResults: [UserSearchResult] = []
    @State private var blends: [GroupResponse] = []
    @State private var aiResults: [SemanticSearchResultItem] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedActor: PersonResult?
    @State private var segment: SearchSegment = .all
    @State private var showPaywall = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var autocompleteSuggestion: String? {
        guard !searchText.isEmpty else { return nil }
        let lower = searchText.lowercased()
        if let movie = results.first, movie.title.lowercased().hasPrefix(lower) {
            return movie.title
        }
        if let actor = actorResults.first, actor.name.lowercased().hasPrefix(lower) {
            return actor.name
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            modeToggle
            resultsBody
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFieldFocused = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            if segment != .assist { debounceSearch(newValue) }
        }
        .task {
            await loadBlends()
        }
        .task(id: debouncedQuery) {
            guard !debouncedQuery.isEmpty, segment != .assist else { return }
            await searchAll(query: debouncedQuery)
        }
        .sheet(item: $selectedActor) { actor in
            NavigationStack {
                ActorProfileView(
                    personId: actor.id,
                    name: actor.name,
                    profilePath: actor.profilePath
                )
            }
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .aiSearch)
                .environment(authState)
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchSegment.allCases) { item in
                    modeChip(item.rawValue, segment: item)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 12)
    }

    private func modeChip(_ label: String, segment item: SearchSegment) -> some View {
        Button {
            segment = item
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(segment == item ? Color.black : Color.white)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(segment == item ? Color.white : AppTheme.card)
                .clipShape(Capsule())
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textDim)
                    .font(.system(size: 15))

                ZStack(alignment: .leading) {
                    // Ghosted autocomplete
                    if let suggestion = autocompleteSuggestion {
                        Button {
                            searchText = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textDim.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(true)
                    }

                    TextField(
                        segment == .assist
                            ? "Describe what you want to watch..."
                            : "Search",
                        text: $searchText
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        if segment == .assist {
                            Task { await aiSearch() }
                        }
                    }
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        debouncedQuery = ""
                        results = []
                        actorResults = []
                        userResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textDim)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(12)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Results

    private var resultsBody: some View {
        GeometryReader { geo in
            ScrollView {
                if segment == .assist {
                    aiResultsBody(cardWidth: (geo.size.width - 24 * 2 - 12) / 2)
                } else {
                    UnifiedSearchResults(
                        segment: segment,
                        movies: results,
                        actors: actorResults,
                        users: userResults,
                        blends: blends,
                        query: debouncedQuery,
                        isLoading: isLoading,
                        hasSearched: hasSearched,
                        onSelectActor: { selectedActor = $0 }
                    )
                }
            }
        }
    }
}

// MARK: - SearchView sections

private extension SearchView {
    @ViewBuilder
    func aiResultsBody(cardWidth: CGFloat) -> some View {
        if isLoading {
            aiLoadingState
        } else if hasSearched, aiResults.isEmpty {
            aiEmptyState
        } else if hasSearched {
            aiResultsGrid(cardWidth: cardWidth)
        } else {
            aiPromptState
        }
    }

    var aiLoadingState: some View {
        AISearchLoadingView()
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    var aiEmptyState: some View {
        VStack(spacing: 8) {
            Text("No results found")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            Text("Try describing the mood or vibe you're looking for")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    func aiResultsGrid(cardWidth: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(aiResults) { movie in
                NavigationLink {
                    MovieDetailView(tmdbId: movie.tmdbId, title: movie.title, source: .search)
                } label: {
                    MovieCard(
                        tmdbId: movie.tmdbId,
                        title: movie.title,
                        year: movie.yearString,
                        posterPath: movie.posterPath,
                        width: cardWidth,
                        height: cardWidth * 1.5
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    var aiPromptState: some View {
        VStack(spacing: 8) {
            Text("Describe what you're in the mood for")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
            Text("\"something like inception\" · \"intense mystery film\"")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textDim.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Search Logic

    func debounceSearch(_ query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            debouncedQuery = ""
            results = []
            actorResults = []
            userResults = []
            hasSearched = false
            return
        }
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            debouncedQuery = trimmed
        }
    }

    func searchAll(query: String) async {
        isLoading = true
        async let movieCall = MoviesAPI.search(query: query)
        async let actorCall = MoviesAPI.searchPerson(query: query)
        async let userCall = AuthAPI.searchUsers(query: query)
        let movies = try? await movieCall
        let actors = try? await actorCall
        let users = try? await userCall
        guard debouncedQuery == query else {
            isLoading = false
            return
        }
        results = movies?.results ?? []
        actorResults = actors?.results ?? []
        userResults = users?.results ?? []
        hasSearched = true
        Analytics.searchPerformed(
            queryLength: query.count,
            resultCount: results.count + actorResults.count + userResults.count
        )
        isLoading = false
    }

    func loadBlends() async {
        blends = await (try? GroupsAPI.listGroups().groups) ?? blends
    }

    func aiSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return }
        isLoading = true
        hasSearched = false
        let isPremium = authState.isPremium
        do {
            let response = try await RecommendationsAPI.semanticSearch(query: trimmed)
            aiResults = response.results
            hasSearched = true
            Analytics.aiSearchPerformed(
                queryLength: trimmed.count,
                resultCount: response.results.count,
                isPremium: isPremium,
                hitRateLimit: false
            )
        } catch APIError.rateLimited {
            showPaywall = true
            Analytics.aiSearchPerformed(
                queryLength: trimmed.count,
                resultCount: 0,
                isPremium: isPremium,
                hitRateLimit: true
            )
        } catch {
            hasSearched = true
            Analytics.aiSearchPerformed(
                queryLength: trimmed.count,
                resultCount: 0,
                isPremium: isPremium,
                hitRateLimit: false
            )
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
