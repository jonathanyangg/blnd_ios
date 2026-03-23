import SwiftUI

struct ScrollHintOverlay: View {
    let onDismiss: () -> Void

    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .background(.ultraThinMaterial)

            VStack(spacing: 16) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)

                Text("Scroll to explore")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)

                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: scrollOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            scrollOffset = 8
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { _ in onDismiss() }
        )
        .onTapGesture { onDismiss() }
    }
}
