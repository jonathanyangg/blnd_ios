import SwiftUI

/// Re-enables the iOS swipe-back gesture on views that hide the navigation back button.
///
/// Uses a narrow edge overlay with `.highPriorityGesture` so the gesture
/// wins over child `NavigationLink`/`Button` taps that happen to sit under
/// the finger's path, while leaving ScrollView scrolling and card taps
/// outside the edge strip untouched.
struct SwipeBackGestureModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: 28)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 8)
                        .onEnded { value in
                            let deltaX = value.translation.width
                            let deltaY = value.translation.height
                            if deltaX > 40, abs(deltaX) > abs(deltaY) * 1.2 {
                                dismiss()
                            }
                        }
                )
                .ignoresSafeArea()
        }
    }
}

extension View {
    func swipeBackGesture() -> some View {
        modifier(SwipeBackGestureModifier())
    }
}
