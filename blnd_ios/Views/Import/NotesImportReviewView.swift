import SwiftUI
import UIKit

/// Hub entry. Pass the note, a paste, or text read from a photo.
func notesImportReview(text: String, onDone: @escaping () -> Void = {}) -> NotesImportReviewView {
    NotesImportReviewView(text: text, onDone: onDone)
}

/// Review matches from a note, then save them to one list.
struct NotesImportReviewView: View {
    let text: String
    var onDone: () -> Void

    init(text: String, onDone: @escaping () -> Void = {}) {
        self.text = text
        self.onDone = onDone
    }

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var items: [NotesReviewItem] = []
    @State private var bucket: NotesImportBucket?
    @State private var isSaving = false
    @State private var commitError: String?
    @State private var savedCount = 0
    @State private var recs: [NotesImportCandidate] = []
    @State private var isDone = false

    private enum Phase {
        case loading
        case review
        case empty
        case failed(String)
    }

    var body: some View {
        Group {
            if isDone {
                doneContent
            } else {
                switch phase {
                case .loading:
                    loadingContent
                case .review:
                    reviewContent
                case .empty:
                    ErrorStateView(
                        message: .client(
                            .notFound,
                            title: "No titles found",
                            message: "We didn't find any titles in that note."
                        )
                    )
                case let .failed(message):
                    ErrorStateView(message: .client(.server, message: message)) {
                        Task { await load() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if isDone { onDone() }
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("import.notes.close")
            }
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .accessibilityIdentifier("import.notes.keyboard.done")
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white)
            Text("Matching your list…")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textMuted)
        }
        .accessibilityIdentifier("import.notes.loading")
    }

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityIdentifier("import.notes.review")
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        row(item)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            if let commitError {
                Text(commitError)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.destructive)
            }

            bucketPicker

            AppButton(
                label: commitLabel,
                isLoading: isSaving,
                isDisabled: bucket == nil || NotesImportReview.selectedIds(from: items).isEmpty
            ) {
                Task { await commit() }
            }
            .accessibilityIdentifier("import.notes.commit")
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
    }

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NotesImportReview.foundTitle(count: savedCount))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityIdentifier("import.notes.found")
                .padding(.top, 8)

            if !recs.isEmpty {
                Text("New for you")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(recs) { movie in
                            recRow(movie)
                        }
                    }
                }
            } else {
                Spacer()
            }

            AppButton(label: "Done") {
                onDone()
                dismiss()
            }
            .accessibilityIdentifier("import.notes.done")
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
    }

    private var bucketPicker: some View {
        HStack(spacing: 8) {
            ForEach(NotesImportBucket.allCases) { choice in
                Button {
                    bucket = choice
                } label: {
                    Text(choice.label)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(bucket == choice ? Color.white : AppTheme.card)
                        .foregroundStyle(bucket == choice ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("import.notes.bucket.\(choice.rawValue)")
                .accessibilityAddTraits(bucket == choice ? .isSelected : [])
            }
        }
    }

    private var commitLabel: String {
        let count = NotesImportReview.selectedIds(from: items).count
        guard let bucket, count > 0 else { return "Save" }
        return "Add \(count) to \(bucket.label)"
    }

    @ViewBuilder
    private func row(_ item: NotesReviewItem) -> some View {
        switch item.confidence {
        case .high:
            if let movie = item.picked {
                confidentRow(item: item, movie: movie)
            }
        case .low:
            choiceRow(item)
        case .none:
            NotesMissRow(item: item) { pick($0, itemId: item.id) }
        }
    }

    private func confidentRow(item: NotesReviewItem, movie: NotesImportCandidate) -> some View {
        Button {
            toggleIncluded(item.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isIncluded ? Color.white : AppTheme.textDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let year = movie.year {
                        Text(String(year))
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("import.notes.include.\(item.id)")
        .accessibilityLabel("\(movie.title), \(item.isIncluded ? "included" : "not included")")
        .accessibilityAddTraits(item.isIncluded ? .isSelected : [])
    }

    private func choiceRow(_ item: NotesReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.query)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
            ForEach(item.candidates) { candidate in
                let picked = item.picked?.tmdbId == candidate.tmdbId && item.isIncluded
                Button {
                    pick(candidate, itemId: item.id)
                } label: {
                    HStack {
                        Text(candidate.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if let year = candidate.year {
                            Text(String(year))
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        Spacer()
                        if picked {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(12)
                    .background(picked ? AppTheme.cardSecondary : AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("import.notes.candidate.\(candidate.tmdbId)")
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private func recRow(_ movie: NotesImportCandidate) -> some View {
        HStack(spacing: 12) {
            poster(movie.posterPath)
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                if let year = movie.year {
                    Text(String(year))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            Spacer()
        }
        .accessibilityIdentifier("import.notes.rec.\(movie.tmdbId)")
    }

    private func poster(_ path: String?) -> some View {
        Group {
            if let path, let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    AppTheme.posterGradient
                }
            } else {
                AppTheme.posterGradient
            }
        }
        .frame(width: 40, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func load() async {
        phase = .loading
        do {
            let note = try NotesImportReview.normalizedText(text)
            let response = try await ImportAPI.importNotes(text: note)
            items = NotesImportReview.items(from: response)
            phase = items.isEmpty ? .empty : .review
        } catch NotesImportError.empty {
            phase = .failed("That note is empty.")
        } catch NotesImportError.tooLong {
            phase = .failed("That note is too long. Split it and try again.")
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private func commit() async {
        guard let bucket else { return }
        let ids = NotesImportReview.selectedIds(from: items)
        guard !ids.isEmpty else { return }
        isSaving = true
        commitError = nil
        defer { isSaving = false }
        do {
            let result = try await ImportAPI.commitNotes(bucket: bucket, tmdbIds: ids)
            savedCount = result.saved
            recs = result.recommendations
            if recs.isEmpty {
                recs = await Self.fallbackRecs(excluding: ids)
            }
            isDone = true
        } catch {
            commitError = Self.message(for: error)
        }
    }

    private func toggleIncluded(_ id: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isIncluded.toggle()
    }

    private func pick(_ candidate: NotesImportCandidate, itemId: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        if items[index].picked?.tmdbId == candidate.tmdbId, items[index].isIncluded {
            items[index].isIncluded = false
            return
        }
        items[index].picked = candidate
        items[index].isIncluded = true
    }

    private static func fallbackRecs(excluding ids: [Int]) async -> [NotesImportCandidate] {
        let exclude = Set(ids)
        guard let response = try? await RecommendationsAPI.getRecommendations(limit: 12) else { return [] }
        return response.results
            .filter { !exclude.contains($0.tmdbId) }
            .prefix(8)
            .map {
                NotesImportCandidate(
                    tmdbId: $0.tmdbId,
                    title: $0.title,
                    year: $0.year,
                    posterPath: $0.posterPath
                )
            }
    }

    private static func message(for error: Error) -> String {
        guard let api = error as? APIError else { return "Something went wrong. Please try again." }
        switch api {
        case .unauthorized:
            return "Sign in to blnd, then try again."
        case .notFound:
            return "Notes import isn't available yet."
        case .networkError:
            return "No connection. Check your internet and try again."
        default:
            return api.localizedDescription ?? "Something went wrong. Please try again."
        }
    }
}

/// Inline search for a title the matcher missed.
private struct NotesMissRow: View {
    let item: NotesReviewItem
    var onPick: (NotesImportCandidate) -> Void

    @State private var query = ""
    @State private var hits: [NotesImportCandidate] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No match for \(item.query)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
            if let picked = item.picked, item.isIncluded {
                Text(picked.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            SearchBar(text: $query, placeholder: "Search title", compact: true)
                .accessibilityIdentifier("import.notes.search.\(item.id)")
            if isSearching {
                ProgressView().tint(.white)
            }
            if let searchError {
                Text(searchError)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.destructive)
            }
            ForEach(hits) { hit in
                Button {
                    onPick(hit)
                } label: {
                    HStack {
                        Text(hit.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        if let year = hit.year {
                            Text(String(year))
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("import.notes.hit.\(hit.tmdbId)")
            }
        }
        .padding(12)
        .background(AppTheme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .onChange(of: query) { _, newValue in
            search(newValue)
        }
        .onDisappear { searchTask?.cancel() }
    }

    private func search(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hits = []
            isSearching = false
            searchError = nil
            return
        }
        isSearching = true
        searchError = nil
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let result = try await MoviesAPI.search(query: trimmed)
                guard !Task.isCancelled else { return }
                hits = result.results.prefix(3).map {
                    NotesImportCandidate(
                        tmdbId: $0.tmdbId,
                        title: $0.title,
                        year: $0.year,
                        posterPath: $0.posterPath
                    )
                }
            } catch {
                if !Task.isCancelled {
                    hits = []
                    searchError = "Search failed. Try again."
                }
            }
            if !Task.isCancelled { isSearching = false }
        }
    }
}
