import SwiftUI

struct ActorSearchSheet: View {
    var onSelect: (PersonResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var results: [PersonResult] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Search Actors")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textDim)
                    .font(.system(size: 15))

                TextField("Search actors...", text: $searchText)
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
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider().overlay(AppTheme.border)

            // Results
            ScrollView {
                if isLoading, results.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if hasSearched, results.isEmpty {
                    VStack(spacing: 8) {
                        Text("No actors found")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Try a different name")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if !results.isEmpty {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { person in
                            actorRow(person)
                        }
                    }
                } else {
                    Text("Search for an actor by name")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
        }
        .background(AppTheme.card)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFieldFocused = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            debounceSearch(newValue)
        }
        .task(id: debouncedQuery) {
            guard !debouncedQuery.isEmpty else { return }
            await search(query: debouncedQuery)
        }
    }

    // MARK: - Actor Row

    private func actorRow(_ person: PersonResult) -> some View {
        Button {
            onSelect(person)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // Headshot
                if let path = person.profilePath {
                    CachedAsyncImage(
                        url: URL(string: "https://image.tmdb.org/t/p/w92\(path)")
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        personPlaceholder
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .posterBlur()
                } else {
                    personPlaceholder
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }

                Text(person.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var personPlaceholder: some View {
        ZStack {
            Circle()
                .fill(AppTheme.background)
            Image(systemName: "person.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textDim)
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
            let response = try await MoviesAPI.searchPerson(query: query)
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
