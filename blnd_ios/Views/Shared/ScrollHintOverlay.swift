import SwiftUI

struct ScrollHintOverlay: View {
    let onDismiss: () -> Void

    @State private var step = 0
    @State private var appeared = false

    private let steps: [String] = [
        "Swipe up to browse movies",
        "Swipe left to add to watchlist",
        "Swipe right to rate a movie",
    ]

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

                Text(steps[step])
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
        switch step {
        case 0: ScrollDemo()
        case 1: SwipeLeftDemo()
        case 2: SwipeRightDemo()
        default: EmptyView()
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

// MARK: - Swipe Left Demo (Watchlist)

private struct SwipeLeftDemo: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.12))
                .frame(width: 140, height: 80)
                .offset(x: phase * -60)
                .opacity(1 - phase * 0.4)

            Image(systemName: "bookmark.fill")
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

// MARK: - Swipe Right Demo (Rate)

private struct SwipeRightDemo: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.12))
                .frame(width: 140, height: 80)
                .offset(x: phase * 60)
                .opacity(1 - phase * 0.4)

            Image(systemName: "star.fill")
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
