import SwiftUI

struct PickGenresView: View {
    private let allGenres = [
        "Action", "Comedy", "Horror", "Sci-Fi", "Romance", "Thriller",
        "Drama", "Animation", "Documentary", "Mystery", "Fantasy", "Crime",
    ]

    @Environment(OnboardingState.self) var onboardingState
    @Binding var path: NavigationPath

    private var canContinue: Bool {
        onboardingState.selectedGenres.count >= 3
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 1, total: 4)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What do you watch?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 40)

                    Text("Pick 3 or more")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    FlowLayout(spacing: 4) {
                        ForEach(allGenres, id: \.self) { genre in
                            GenrePill(
                                label: genre,
                                isActive: onboardingState.selectedGenres.contains(genre)
                            ) {
                                if onboardingState.selectedGenres.contains(genre) {
                                    onboardingState.selectedGenres.remove(genre)
                                } else {
                                    onboardingState.selectedGenres.insert(genre)
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 24)

                    AppButton(label: "Continue", isDisabled: !canContinue) {
                        path.append(AuthRoute.rateMovies)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var xPos: CGFloat = 0
        var yPos: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if xPos + size.width > width, xPos > 0 {
                xPos = 0
                yPos += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: xPos, y: yPos))
            rowHeight = max(rowHeight, size.height)
            xPos += size.width + spacing
        }

        return (positions, CGSize(width: width, height: yPos + rowHeight))
    }
}

#Preview {
    NavigationStack {
        PickGenresView(path: .constant(NavigationPath()))
            .environment(OnboardingState())
    }
}
