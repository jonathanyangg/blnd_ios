import SwiftUI

// MARK: - Tap-to-play trailer

extension ReelCardView {
    /// Tap the poster: play the trailer full-bleed with every overlay hidden.
    /// Tap again to stop. Details stay on the "Details" chip (high-priority tap).
    func posterTapped() {
        guard !showsTutorial, !isDragging else { return }
        apply(hold.send(.tapped))
    }

    private func hideUnavailableSoon() {
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showTrailerUnavailable = false
        }
    }

    func apply(_ effect: TrailerPlaybackState.Effect) {
        switch effect {
        case .play:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // A tap is an explicit "watch this", so play with sound.
            TrailerPlayer.shared.setMuted(false)
            startTrailer()
        case .stop:
            trailerTask?.cancel()
            trailerKind = nil
            TrailerPlayer.shared.stop()
        case .ignore:
            break
        }
    }

    private func startTrailer() {
        trailerTask?.cancel()
        trailerTask = Task {
            let kind = APIConfig.screenshotMode
                ? TrailerSourceKind.unavailable
                : await TrailerSource.shared.resolve(
                    tmdbId: movie.tmdbId,
                    title: movie.title,
                    year: Int(movie.yearString),
                    trailerUrl: movie.trailerUrl
                )
            guard !Task.isCancelled, hold.isPlaying else { return }
            switch kind {
            case let .native(url):
                trailerKind = kind
                TrailerPlayer.shared.playNative(url: url)
            case let .youtube(id):
                trailerKind = kind
                TrailerPlayer.shared.play(videoId: id)
            case .unavailable:
                apply(hold.send(.stopped))
                showTrailerUnavailable = true
                hideUnavailableSoon()
            }
        }
    }

    /// Poster stays visible until the player reports frames, so there is no black flash.
    @ViewBuilder
    var trailerLayer: some View {
        if hold.isPlaying, let trailerKind {
            Group {
                switch trailerKind {
                case .native:
                    NativeTrailerView(player: TrailerPlayer.shared.nativePlayer)
                case let .youtube(id):
                    ReelTrailerView(videoId: id)
                case .unavailable:
                    EmptyView()
                }
            }
            .opacity(TrailerPlayer.shared.isPlaying ? 1 : 0)
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    /// Nothing but the video while playing. The invisible marker keeps the UI-test hook.
    @ViewBuilder
    var trailerHUD: some View {
        if hold.isPlaying {
            Color.clear
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel("Trailer playing. Tap to stop.")
                .accessibilityIdentifier("reel.trailer.playing")
        } else if showTrailerUnavailable {
            Text("No trailer available")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
                .accessibilityIdentifier("reel.trailer.unavailable")
                .transition(.opacity)
        }
    }

    func loadProviders() async {
        guard providers.isEmpty, !APIConfig.screenshotMode,
              let response = try? await MoviesAPI.getStreaming(
                  tmdbId: movie.tmdbId,
                  mediaType: movie.mediaType ?? .movie
              )
        else { return }
        providers = response.whereToWatch?.offers(.watchNow) ?? []
    }
}
