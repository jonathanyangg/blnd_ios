import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var results: [MovieResponse] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var debounceTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textDim)
                        .font(.system(size: 15))

                    TextField("Search movies...", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .focused($isFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            debouncedQuery = ""
                            results = []
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

            // Results
            GeometryReader { geo in
                ScrollView {
                    if isLoading, results.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if hasSearched, results.isEmpty {
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
                    } else if !results.isEmpty {
                        let cardWidth = (geo.size.width - 24 * 2 - 12) / 2
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(results) { movie in
                                NavigationLink {
                                    MovieDetailView(tmdbId: movie.tmdbId, title: movie.title)
                                } label: {
                                    MovieCard(
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
                    } else {
                        // Empty state before typing
                        Text("Search for movies by title")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .onAppear {
            isFieldFocused = true
        }
        .onChange(of: searchText) { _, newValue in
            debounceSearch(newValue)
        }
        .task(id: debouncedQuery) {
            guard !debouncedQuery.isEmpty else { return }
            await search(query: debouncedQuery)
        }
    }

    // MARK: - Debounce

    private func debounceSearch(_ query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            debouncedQuery = ""
            results = []
            hasSearched = false
            return
        }
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            debouncedQuery = trimmed
        }
    }

    private func search(query: String) async {
        isLoading = true
        do {
            let response = try await MoviesAPI.search(query: query)
            if debouncedQuery == query {
                results = response.results
                hasSearched = true
            }
        } catch {
            if !Task.isCancelled {
                hasSearched = true
            }
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
