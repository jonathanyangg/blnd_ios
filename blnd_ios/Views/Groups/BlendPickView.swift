import SwiftUI

/// "Find a movie for us": one pick from the blend's recommendations, with where-to-watch and log actions.
struct BlendPickView: View {
    @State var model: BlendPickModel

    @Environment(\.dismiss) private var dismiss
    @State private var showStreaming = false
    @State private var showLog = false
    @State private var loggedRating: Double?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            switch model.phase {
            case .loading:
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            case .empty:
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "star.leadinghalf.filled")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textDim)
                    Text("No pick yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Rate a few movies (and get your friends to) so we can find one you'll all like.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .accessibilityIdentifier("blend.pick.empty")
                Spacer()
            case let .failed(error):
                Spacer()
                ErrorStateView(message: error) {
                    Task { await model.load() }
                }
                Spacer()
            case .ready:
                if let movie = model.deck.current {
                    pickCard(movie)
                }
            }
        }
        .task { await model.load() }
    }

    private func pickCard(_ movie: GroupRecMovieResponse) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                PosterTile(posterPath: movie.posterPath, rating: nil)
                    .frame(width: 200, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                VStack(spacing: 4) {
                    Text(movie.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("blend.pick.title")
                    Text([movie.yearString, "\(movie.scorePercent)% match"]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                }

                if let reason = movie.reason, !reason.isEmpty {
                    Text("Why this pick: \(reason)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("blend.pick.reason")
                }

                if let loggedRating {
                    Text("Logged · \(String(format: "%.1f", loggedRating))★ Enjoy!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("blend.done")
                }

                VStack(spacing: 10) {
                    AppButton(label: "Where to watch") { showStreaming = true }
                        .accessibilityIdentifier("blend.whereToWatch")
                    AppButton(label: "We watched it", style: .ghost) { showLog = true }
                        .accessibilityIdentifier("blend.watched")
                    if model.deck.movies.count > 1 {
                        AppButton(label: "Another pick", style: .ghost) {
                            loggedRating = nil
                            model.anotherPick()
                        }
                        .accessibilityIdentifier("blend.anotherPick")
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showStreaming) {
            StreamingSheet(tmdbId: movie.tmdbId, title: movie.title)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.card)
        }
        .sheet(isPresented: $showLog) {
            RateMovieSheet(
                title: movie.title,
                year: movie.yearString,
                tmdbId: movie.tmdbId,
                posterPath: movie.posterPath,
                existingRating: UserActionCache.shared.rating(for: movie.tmdbId)
            ) { rating in
                loggedRating = rating
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.card)
        }
    }
}
