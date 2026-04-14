import SwiftUI

// MARK: - Tutorial Step Config

enum TutorialDemo {
    case scrollUp
    case swipeLeft
    case swipeRight
    case rateButton
    case forYouTaste
}

struct TutorialStep {
    let text: String
    let demo: TutorialDemo
}

// MARK: - Presets

enum TutorialPreset {
    static let reels: [TutorialStep] = [
        .init(
            text: "Movies picked just for you",
            demo: .forYouTaste
        ),
        .init(
            text: "Swipe right to add to watchlist",
            demo: .swipeRight
        ),
        .init(
            text: "Swipe left to dislike",
            demo: .swipeLeft
        ),
        .init(
            text: "Tap a star to rate instantly",
            demo: .rateButton
        ),
    ]
}

// MARK: - Overlay

struct ScrollHintOverlay: View {
    var steps: [TutorialStep] = TutorialPreset.reels
    let onDismiss: () -> Void

    @State private var step = 0
    @State private var appeared = false

    private var isLastStep: Bool {
        step >= steps.count - 1
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.75 : 0)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                gestureDemo
                    .frame(height: 160)
                    .id(step)

                Text(steps[step].text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 32)
                    .id("text-\(step)")
                    .transition(.opacity)

                Spacer()

                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(
                            0 ..< steps.count,
                            id: \.self
                        ) { idx in
                            Circle()
                                .fill(
                                    idx == step
                                        ? .white
                                        : AppTheme.textDim
                                )
                                .frame(width: 6, height: 6)
                        }
                    }

                    Button {
                        if isLastStep {
                            dismiss()
                        } else {
                            withAnimation(
                                .easeInOut(duration: 0.3)
                            ) {
                                step += 1
                            }
                        }
                    } label: {
                        Text(isLastStep ? "Got it" : "Next")
                            .font(.system(
                                size: 16, weight: .semibold
                            ))
                            .foregroundStyle(.black)
                            .frame(width: 200, height: 48)
                            .background(.white)
                            .clipShape(Capsule())
                    }

                    if !isLastStep {
                        Button { dismiss() } label: {
                            Text("Skip")
                                .font(.system(size: 14))
                                .foregroundStyle(
                                    AppTheme.textMuted
                                )
                        }
                    }
                }
                .padding(.bottom, 60)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var gestureDemo: some View {
        switch steps[step].demo {
        case .scrollUp: ScrollDemo()
        case .swipeLeft: SwipeLeftDemo()
        case .swipeRight: SwipeRightDemo()
        case .rateButton: RateButtonDemo()
        case .forYouTaste: ForYouTasteDemo()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.25
        ) {
            onDismiss()
        }
    }
}

// MARK: - Scroll Demo (Swipe Up)

private struct ScrollDemo: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            // Card stack
            VStack(spacing: 8) {
                pill
                pill.opacity(0.5)
                pill.opacity(0.25)
            }
            .offset(y: animating ? -30 : 10)

            // Arrow
            Image(systemName: "chevron.up")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .offset(y: 70)
                .offset(y: animating ? -20 : 0)
                .opacity(animating ? 0 : 1)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }

    private var pill: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.white.opacity(0.12))
            .frame(width: 120, height: 32)
    }
}

// MARK: - Swipe Left Demo (Skip / Hide)

private struct SwipeLeftDemo: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.12))
                .frame(width: 140, height: 80)
                .offset(x: phase * -60)
                .opacity(1.0 - (phase * 0.4))

            Image(systemName: "hand.thumbsdown.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(phase))
                .offset(x: -40)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }
}

// MARK: - Swipe Right Demo (Watchlist)

private struct SwipeRightDemo: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.12))
                .frame(width: 140, height: 80)
                .offset(x: phase * 60)
                .opacity(1.0 - (phase * 0.4))

            Image(systemName: "bookmark.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(phase))
                .offset(x: 40)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }
}

// MARK: - Rate Button Demo

private struct RateButtonDemo: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.12))
                .frame(width: 140, height: 80)

            // Rate button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "star")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.white.opacity(pulse ? 0.3 : 0.1))
                        )
                        .scaleEffect(pulse ? 1.15 : 1)
                }
                Spacer()
            }
            .frame(width: 140, height: 80)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}

// MARK: - For You Taste Demo

private struct ForYouTasteDemo: View {
    @State private var merged = false

    var body: some View {
        ZStack {
            HStack(spacing: merged ? 0 : 40) {
                filmCircle
                filmCircle
                filmCircle
            }
            .opacity(merged ? 0 : 1)

            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(AppTheme.aiGradient)
                .opacity(merged ? 1 : 0)
                .scaleEffect(merged ? 1 : 0.5)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
            ) {
                merged = true
            }
        }
    }

    private var filmCircle: some View {
        Circle()
            .fill(.white.opacity(0.15))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }
    }
}
