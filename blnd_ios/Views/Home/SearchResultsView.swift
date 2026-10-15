import SwiftUI

private enum SearchMode {
    case movies
    case people
    case blends
    case aiSearch
}

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
    @State private var isLoadingBlends = false
    @State private var blendLoadFailed = false
    @State private var aiResults: [SemanticSearchResultItem] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedActor: PersonResult?
    @State private var searchMode: SearchMode = .movies
    @State private var showPaywall = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var autocompleteSuggestion: String? {
        guard !searchText.isEmpty else { return nil }
        let lower = searchText.lowercased()
        switch searchMode {
        case .people:
            if let actor = actorResults.first, actor.name.lowercased().hasPrefix(lower) {
                return actor.name
            }
            if let user = userResults.first {
                let name = user.displayName ?? user.username
                if name.lowercased().hasPrefix(lower) { return name }
            }
        case .movies:
            if let movie = results.first, movie.title.lowercased().hasPrefix(lower) {
                return movie.title
            }
        case .blends, .aiSearch:
            break
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
            if searchMode == .movies || searchMode == .people {
                debounceSearch(newValue)
            }
        }
        .onChange(of: searchMode) {
            results = []
            actorResults = []
            userResults = []
            aiResults = []
            hasSearched = false
            if searchMode == .blends {
                Task { await loadBlends() }
            } else if searchMode == .movies || searchMode == .people {
                debounceSearch(searchText)
            }
        }
        .task(id: debouncedQuery) {
            guard !debouncedQuery.isEmpty else { return }
            switch searchMode {
            case .movies:
                await searchMovies(query: debouncedQuery)
            case .people:
                await searchPeople(query: debouncedQuery)
            case .blends, .aiSearch:
                break
            }
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
                modeChip("Movies", mode: .movies, icon: "film")
                modeChip("People", mode: .people, icon: "person")
                modeChip("Blends", mode: .blends, icon: "person.3")
                modeChip("AI Search", mode: .aiSearch, icon: "sparkles")
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 12)
    }

    private func modeChip(
        _ label: String,
        mode: SearchMode,
        icon: String
    ) -> some View {
        Button {
            searchMode = mode
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(
                searchMode == mode
                    ? AnyShapeStyle(Color.black)
                    : AnyShapeStyle(Color.white)
            )
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(searchMode == mode ? .white : AppTheme.card)
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

                    TextField(searchPlaceholder, text: $searchText)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .focused($isFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            if searchMode == .aiSearch {
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
                let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
                switch searchMode {
                case .aiSearch:
                    aiResultsBody(cardWidth: cardWidth)
                case .movies:
                    movieResults(cardWidth: cardWidth)
                case .people:
                    PeopleSearchResults(
                        actors: actorResults,
                        users: userResults,
                        isLoading: isLoading,
                        hasSearched: hasSearched,
                        query: debouncedQuery,
                        onSelectActor: { selectedActor = $0 }
                    )
                case .blends:
                    BlendSearchResults(
                        blends: blends,
                        isLoading: isLoadingBlends,
                        loadFailed: blendLoadFailed,
                        query: searchText
                    )
                }
            }
        }
    }

    private var searchPlaceholder: String {
        switch searchMode {
        case .movies: "Search movies..."
        case .people: "Search people..."
        case .blends: "Search blends..."
        case .aiSearch: "Describe what you want to watch..."
        }
    }

    private func moviePrompt(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private func movieResults(cardWidth: CGFloat) -> some View {
        Group {
            if isLoading, results.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if hasSearched, results.isEmpty {
                moviePrompt("No movies for \"\(debouncedQuery)\"")
            } else if hasSearched {
                moviesSection(cardWidth: cardWidth)
            } else {
                moviePrompt("Search for movies")
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

    // MARK: - Movies Section

    func moviesSection(cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(results) { movie in
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

    func searchMovies(query: String) async {
        isLoading = true
        do {
            let movies = try await MoviesAPI.search(query: query)
            if debouncedQuery == query, searchMode == .movies {
                results = movies.results
                hasSearched = true
                Analytics.searchPerformed(
                    queryLength: query.count,
                    resultCount: movies.results.count
                )
            }
        } catch {
            if !Task.isCancelled {
                hasSearched = true
                Analytics.searchPerformed(queryLength: query.count, resultCount: 0)
            }
        }
        isLoading = false
    }

    func searchPeople(query: String) async {
        isLoading = true
        async let actorCall = MoviesAPI.searchPerson(query: query)
        async let userCall = AuthAPI.searchUsers(query: query)
        let actors = try? await actorCall
        let users = try? await userCall
        if debouncedQuery == query, searchMode == .people {
            actorResults = actors?.results ?? []
            userResults = users?.results ?? []
            hasSearched = true
            Analytics.searchPerformed(
                queryLength: query.count,
                resultCount: actorResults.count + userResults.count
            )
        }
        isLoading = false
    }

    func loadBlends() async {
        isLoadingBlends = true
        blendLoadFailed = false
        defer { isLoadingBlends = false }
        do {
            blends = try await GroupsAPI.listGroups().groups
        } catch {
            blendLoadFailed = blends.isEmpty
        }
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
