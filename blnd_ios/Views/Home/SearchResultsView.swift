import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState
    @FocusState private var isFieldFocused: Bool

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var results: [MovieResponse] = []
    @State private var tvResults: [TVShowResponse] = []
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
    @State private var searchFailed = false
    @State private var recents = RecentSearchesStore()

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
                CatalogFilterButton()
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
                    .accessibilityIdentifier("search.field")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        if segment == .assist {
                            Task { await aiSearch() }
                        } else {
                            runSearch(searchText)
                        }
                    }
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        debouncedQuery = ""
                        results = []
                        tvResults = []
                        actorResults = []
                        userResults = []
                        hasSearched = false
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textDim)
                            .font(.system(size: 16))
                    }
                    .accessibilityIdentifier("search.clear")
                    .accessibilityLabel("Clear search")
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
                } else if showsRecents {
                    recentSection
                } else if searchFailed, hasSearched, !isLoading {
                    errorState
                } else {
                    UnifiedSearchResults(
                        segment: segment,
                        movies: results,
                        shows: tvResults,
                        actors: actorResults,
                        users: userResults,
                        blends: blends,
                        query: debouncedQuery,
                        isLoading: isLoading,
                        hasSearched: hasSearched,
                        onSelectActor: { selectedActor = $0 },
                        onSelectResult: { recents.record(debouncedQuery) }
                    )
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }
}

// MARK: - SearchView sections

private extension SearchView {
    var showsRecents: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty && !recents.items.isEmpty
    }

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent searches")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Clear all") { recents.clearAll() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .accessibilityIdentifier("search.recent.clearAll")
            }
            .padding(.bottom, 6)
            ForEach(Array(recents.items.enumerated()), id: \.element) { index, query in
                HStack(spacing: 12) {
                    Button { runSearch(query) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textDim)
                            Text(query)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.recent.item.\(index)")
                    Button { recents.remove(query) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textDim)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityIdentifier("search.recent.delete.\(index)")
                    .accessibilityLabel("Remove \(query)")
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.recent.section")
    }

    var errorState: some View {
        VStack(spacing: 8) {
            Text("Couldn't load results")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            Text("Check your connection and try again")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    /// Submit or tap on a recent item: search now (skip the debounce) and remember it.
    func runSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searchText = trimmed
        debounceTask?.cancel()
        debouncedQuery = trimmed
        recents.record(trimmed)
        isFieldFocused = false
    }

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
                SearchResultCard(
                    tmdbId: movie.tmdbId,
                    title: movie.title,
                    year: movie.yearString,
                    posterPath: movie.posterPath,
                    mediaType: movie.mediaType,
                    cardWidth: cardWidth
                )
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
            tvResults = []
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
        let filter = CatalogFilterStore.shared.current()
        let years = filter.yearsOnly
        async let actorCall = MoviesAPI.searchPerson(query: query)
        async let userCall = AuthAPI.searchUsers(query: query)
        let movies = filter.media == .tv
            ? nil
            : try? await MoviesAPI.search(query: query, filter: years)
        let shows = filter.media == .movies
            ? nil
            : try? await TVAPI.search(query: query, filter: years)
        let actors = try? await actorCall
        let users = try? await userCall
        guard debouncedQuery == query else {
            isLoading = false
            return
        }
        results = (movies?.results ?? []).filter {
            filter.matches(mediaType: $0.mediaType ?? .movie, year: $0.year)
        }
        tvResults = (shows?.results ?? []).filter {
            filter.matches(mediaType: .tv, year: $0.year)
        }
        actorResults = actors?.results ?? []
        userResults = users?.results ?? []
        // Every request that ran failed (the skipped media call is nil by design).
        searchFailed = movies == nil && shows == nil && actors == nil && users == nil
        hasSearched = true
        Analytics.searchPerformed(
            queryLength: query.count,
            resultCount: results.count + tvResults.count
                + actorResults.count + userResults.count
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
