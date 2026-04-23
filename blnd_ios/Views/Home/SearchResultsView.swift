import SwiftUI

private enum SearchMode {
    case standard
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
    @State private var aiResults: [SemanticSearchResultItem] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedActor: PersonResult?
    @State private var searchMode: SearchMode = .standard
    @State private var showPaywall = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var autocompleteSuggestion: String? {
        guard !searchText.isEmpty else { return nil }
        let lower = searchText.lowercased()
        // Check actors first, then movies
        if let actor = actorResults.first, actor.name.lowercased().hasPrefix(lower) {
            return actor.name
        }
        if let movie = results.first, movie.title.lowercased().hasPrefix(lower) {
            return movie.title
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
            if searchMode == .standard {
                debounceSearch(newValue)
            }
        }
        .onChange(of: searchMode) {
            // Clear results when switching modes
            results = []
            actorResults = []
            aiResults = []
            hasSearched = false
        }
        .task(id: debouncedQuery) {
            guard !debouncedQuery.isEmpty else { return }
            if searchMode == .standard {
                await search(query: debouncedQuery)
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
            PaywallView()
                .environment(authState)
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 8) {
            modeChip("Movies", mode: .standard, icon: "film")
            modeChip("AI Search", mode: .aiSearch, icon: "sparkles")
            Spacer()
        }
        .padding(.horizontal, 24)
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

                    TextField(
                        searchMode == .aiSearch
                            ? "Describe what you want to watch..."
                            : "Search movies & actors...",
                        text: $searchText
                    )
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
                if searchMode == .aiSearch {
                    aiResultsBody(cardWidth: (geo.size.width - 24 * 2 - 12) / 2)
                } else {
                    standardResultsBody(cardWidth: (geo.size.width - 24 * 2 - 12) / 2)
                }
            }
        }
    }

    private func standardResultsBody(cardWidth: CGFloat) -> some View {
        Group {
            if isLoading, results.isEmpty, actorResults.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if hasSearched, results.isEmpty, actorResults.isEmpty {
                VStack(spacing: 8) {
                    Text("No results for \"\(debouncedQuery)\"")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Try a different search term")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if hasSearched {
                VStack(alignment: .leading, spacing: 0) {
                    if !actorResults.isEmpty {
                        actorsSection
                    }
                    if !results.isEmpty {
                        moviesSection(cardWidth: cardWidth)
                    }
                }
            } else {
                Text("Search for movies & actors")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        }
    }

    @ViewBuilder
    private func aiResultsBody(cardWidth: CGFloat) -> some View {
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

    private var aiLoadingState: some View {
        AISearchLoadingView()
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }

    private var aiEmptyState: some View {
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

    private func aiResultsGrid(cardWidth: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(aiResults) { movie in
                NavigationLink {
                    MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
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

    private var aiPromptState: some View {
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
}

// MARK: - SearchView sections

private extension SearchView {
    // MARK: - Actors Section

    var actorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actors")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(actorResults) { actor in
                        Button {
                            selectedActor = actor
                        } label: {
                            actorChip(actor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 20)
    }

    func actorChip(_ actor: PersonResult) -> some View {
        VStack(spacing: 4) {
            Group {
                let base = "https://image.tmdb.org/t/p/w185"
                if let path = actor.profilePath, let url = URL(string: "\(base)\(path)") {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.card)
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(AppTheme.card)
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textDim)
                    }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            Text(actor.name)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
                .lineLimit(1)
                .frame(width: 56)
        }
    }

    // MARK: - Movies Section

    func moviesSection(cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !actorResults.isEmpty {
                Text("Movies")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(results) { movie in
                    NavigationLink {
                        MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
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
            hasSearched = false
            return
        }
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            debouncedQuery = trimmed
        }
    }

    func search(query: String) async {
        isLoading = true
        do {
            async let movieResponse = MoviesAPI.search(query: query)
            async let actorResponse = MoviesAPI.searchPerson(query: query)
            let (movies, actors) = try await (movieResponse, actorResponse)
            if debouncedQuery == query {
                results = movies.results
                actorResults = actors.results
                hasSearched = true
            }
        } catch {
            if !Task.isCancelled {
                hasSearched = true
            }
        }
        isLoading = false
    }

    func aiSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return }
        isLoading = true
        hasSearched = false
        do {
            let response = try await RecommendationsAPI.semanticSearch(query: trimmed)
            aiResults = response.results
            hasSearched = true
        } catch APIError.rateLimited(_) {
            showPaywall = true
        } catch {
            hasSearched = true
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
