import SwiftUI

// MARK: - Hold-to-play trailer

extension ReelCardView {
    func holdBegan() {
        guard !showsTutorial, !isDragging else { return }
        holdTouchActive = true
        apply(hold.send(.pressBegan))
        lockTask?.cancel()
        lockTask = Task {
            try? await Task.sleep(for: .seconds(0.75))
            guard !Task.isCancelled else { return }
            apply(hold.send(.pressHeldLong))
        }
    }

    func holdEnded() {
        lockTask?.cancel()
        holdTouchActive = false
        // The tap recognizer may also fire for the lifting finger. Swallow it.
        suppressTapUntil = Date().addingTimeInterval(0.35)
        apply(hold.send(.released))
        if showTrailerUnavailable { hideUnavailableSoon() }
    }

    /// The toast stays up while the finger is down, then 1.5s after.
    private func hideUnavailableSoon() {
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !holdTouchActive { showTrailerUnavailable = false }
        }
    }

    func posterTapped() {
        guard !isDragging, !holdTouchActive, Date() > suppressTapUntil else { return }
        apply(hold.send(.tapped))
    }

    func apply(_ effect: TrailerHoldState.Effect) {
        switch effect {
        case .play:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            startTrailer()
        case .lock:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                if !holdTouchActive { hideUnavailableSoon() }
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

    @ViewBuilder
    var trailerHUD: some View {
        if hold.isPlaying {
            VStack {
                HStack(spacing: 10) {
                    if !TrailerPlayer.shared.isPlaying {
                        ProgressView().tint(.white)
                    }
                    Spacer()
                    if hold.phase == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .accessibilityLabel("Trailer locked on. Tap to stop.")
                    }
                    soundToggle
                }
                .padding(16)
                Spacer()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reel.trailer.playing")
            .transition(.opacity)
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

    private var soundToggle: some View {
        let muted = TrailerPlayer.shared.isMuted
        return Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: Circle())
            .environment(\.colorScheme, .dark)
            .contentShape(Circle())
            .highPriorityGesture(
                TapGesture().onEnded { TrailerPlayer.shared.setMuted(!muted) }
            )
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(muted ? "Unmute trailer" : "Mute trailer")
            .accessibilityIdentifier("reel.sound.toggle")
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
