import SwiftUI

struct ScrollHintOverlay: View {
    let onDismiss: () -> Void

    @State private var step = 0
    @State private var appeared = false

    private let steps: [(icon: String, text: String)] = [
        ("arrow.up.arrow.down", "Swipe up or down to browse movies"),
        ("arrow.left", "Swipe left to add to your watchlist"),
        ("arrow.right", "Swipe right to rate a movie"),
    ]

    private var isLastStep: Bool {
        step >= steps.count - 1
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.7 : 0)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: steps[step].icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .id(step)

                // Text
                Text(steps[step].text)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .id("text-\(step)")
                    .transition(.opacity)

                Spacer()

                // Dots + button
                VStack(spacing: 24) {
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0 ..< steps.count, id: \.self) { idx in
                            Circle()
                                .fill(idx == step ? .white : AppTheme.textDim)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Button {
                        if isLastStep {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step += 1
                            }
                        }
                    } label: {
                        Text(isLastStep ? "Got it" : "Next")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 200, height: 48)
                            .background(.white)
                            .clipShape(Capsule())
                    }

                    if !isLastStep {
                        Button { dismiss() } label: {
                            Text("Skip")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textMuted)
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

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
