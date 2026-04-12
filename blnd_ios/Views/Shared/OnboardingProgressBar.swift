import SwiftUI

struct OnboardingProgressBar: View {
    /// Current step (1-based)
    let step: Int
    /// Total number of steps
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.card)
                    .frame(height: 2)

                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: geo.size.width * CGFloat(step) / CGFloat(total), height: 2)
                    .animation(.easeInOut(duration: 0.4), value: step)
            }
        }
        .frame(height: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingProgressBar(step: 1, total: 5)
        OnboardingProgressBar(step: 2, total: 5)
        OnboardingProgressBar(step: 3, total: 5)
        OnboardingProgressBar(step: 4, total: 5)
        OnboardingProgressBar(step: 5, total: 5)
    }
    .padding()
    .background(AppTheme.background)
}
