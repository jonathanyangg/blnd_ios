import SwiftUI

/// Dated, poster-forward history used on profiles and blends.
struct WatchTimelineScreen: View {
    enum Source {
        case own
        case user(String)
        case blend(Int)
        case preview([TimelineEntry])
    }

    let source: Source
    var showsViewer = false
    var embedsInParentScroll = false
    var emptyTitle = "Nothing here yet"
    var emptyMessage = "Movies you watch will show up here."
    var unavailableTitle = DiaryCopy.diaryUnavailableTitle
    var unavailableMessage = DiaryCopy.diaryUnavailableMessage
    var detailSource: Analytics.DetailSource = .profile
    var reloadToken = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entries: [TimelineEntry] = []
    @State private var nextCursor: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var failure: TimelineLoadFailure?
    @State private var loadGeneration = 0

    var body: some View {
        Group {
            if embedsInParentScroll {
                timelineBody
            } else {
                ScrollView {
                    timelineBody
                        .padding(.top, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .task { await loadFirst() }
        .onChange(of: reloadToken) { _, token in
            guard token > 0 else { return }
            Task { await loadFirst() }
        }
    }

    @ViewBuilder
    private var timelineBody: some View {
        if isLoading, entries.isEmpty {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else if entries.isEmpty, let failure {
            failureView(failure)
        } else if entries.isEmpty {
            emptyView
        } else {
            loadedList
        }
    }

    private var loadedList: some View {
        let sections = TimelineGrouping.sections(from: entries)
        return LazyVStack(alignment: .leading, spacing: 12, pinnedViews: embedsInParentScroll ? [] : [.sectionHeaders]) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        NavigationLink {
                            MovieDetailView(tmdbId: entry.media.tmdbId, title: entry.media.title, source: detailSource)
                        } label: {
                            TimelineEntryCard(entry: entry, showsViewer: showsViewer, reduceMotion: reduceMotion)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .onAppear {
                            guard entry.id == entries.last?.id else { return }
                            Task { await loadMore() }
                        }
                    }
                } header: {
                    Text(section.title)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(AppTheme.background)
                }
            }

            if isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if failure != nil {
                Button {
                    Task { await loadFirst() }
                } label: {
                    Text("Couldn't update this list. Tap to retry.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.bottom, 32)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.textDim)
            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(emptyMessage)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 48)
    }

    @ViewBuilder
    private func failureView(_ failure: TimelineLoadFailure) -> some View {
        switch failure {
        case .unavailable:
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(AppTheme.textDim)
                Text(unavailableTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(unavailableMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                retryButton
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 48)
        case let .message(message):
            ErrorStateView(message: .client(.server, message: message)) {
                Task { await loadFirst() }
            }
            .padding(.top, 32)
        }
    }

    private var retryButton: some View {
        Button {
            Task { await loadFirst() }
        } label: {
            Text("Retry")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(Capsule())
        }
        .padding(.top, 4)
    }

    private func loadFirst() async {
        if case let .preview(items) = source {
            entries = items
            nextCursor = nil
            failure = nil
            isLoading = false
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        failure = nil
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let page = try await fetch(cursor: nil)
            guard generation == loadGeneration else { return }
            entries = page.results
            nextCursor = page.nextCursor
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            failure = TimelineLoadFailure.from(error)
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoading, !isLoadingMore else { return }
        let generation = loadGeneration
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetch(cursor: cursor)
            guard generation == loadGeneration else { return }
            if page.results.isEmpty {
                nextCursor = nil
                return
            }
            var seen = Set(entries.map(\.id))
            var added = 0
            for entry in page.results where seen.insert(entry.id).inserted {
                entries.append(entry)
                added += 1
            }
            nextCursor = added == 0 ? nil : page.nextCursor
            failure = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            failure = TimelineLoadFailure.from(error)
        }
    }

    private func fetch(cursor: String?) async throws -> TimelinePage {
        switch source {
        case .own:
            try await TimelineAPI.own(cursor: cursor)
        case let .user(userId):
            try await TimelineAPI.user(userId, cursor: cursor)
        case let .blend(groupId):
            try await TimelineAPI.blend(groupId, cursor: cursor)
        case let .preview(items):
            TimelinePage(results: items, nextCursor: nil)
        }
    }
}

private struct TimelineEntryCard: View {
    let entry: TimelineEntry
    let showsViewer: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            poster
                .frame(width: 92, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let day = TimelineDate.dayParts(of: entry) {
                    Text(TimelineDate.weekdayAndDay(day))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textDim)
                }

                Text(entry.media.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let year = entry.media.year {
                    Text(String(year))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textDim)
                }

                if let rating = entry.rating {
                    TimelineStars(rating: rating)
                }

                if showsViewer {
                    HStack(spacing: 6) {
                        AvatarView(url: entry.user.avatar, size: 18)
                        Text(entry.user.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                if let line = DiaryCopy.watchedWithLine(entry.watchedWith) {
                    Text(line)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(reduceMotion || phase.isIdentity ? 1 : 0.7)
                .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.98)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var poster: some View {
        ZStack(alignment: .topLeading) {
            posterImage
            if entry.media.isTV {
                Text("TV")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(6)
                    .accessibilityIdentifier("tv-show-badge")
            }
        }
    }

    private var posterImage: some View {
        Group {
            if let url = posterURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill).posterBlur()
                } placeholder: {
                    posterFallback
                }
            } else {
                posterFallback
            }
        }
    }

    private var posterURL: URL? {
        guard let poster = entry.media.poster, !poster.isEmpty else { return nil }
        if poster.hasPrefix("http://") || poster.hasPrefix("https://") {
            return URL(string: poster)
        }
        let path = poster.hasPrefix("/") ? poster : "/\(poster)"
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    private var posterFallback: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.posterGradient(angle: entry.media.tmdbId * 37))
            .overlay {
                Image(systemName: entry.media.isTV ? "tv" : "film")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }

    private var accessibilityText: String {
        var parts = [entry.media.title]
        if entry.media.isTV { parts.append("TV show") }
        if let day = TimelineDate.dayParts(of: entry) {
            parts.append("\(TimelineDate.monthName(day.month)) \(day.day), \(day.year)")
        }
        if let rating = entry.rating {
            parts.append("rated \(rating)")
        }
        if showsViewer {
            parts.append("logged by \(entry.user.name)")
        }
        if let line = DiaryCopy.watchedWithLine(entry.watchedWith) {
            parts.append(line)
        }
        return parts.joined(separator: ", ")
    }
}

private struct TimelineStars: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1 ... 5, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(.white)
        .accessibilityLabel("Rated \(rating) out of 5")
    }

    private func symbol(for index: Int) -> String {
        let value = Double(index)
        if rating >= value { return "star.fill" }
        if rating >= value - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}
