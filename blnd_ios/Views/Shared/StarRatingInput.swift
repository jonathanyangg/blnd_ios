import SwiftUI

struct StarRatingInput: View {
    @Binding var rating: Double
    var starSize: CGFloat = 28
    var spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1 ... 5, id: \.self) { index in
                starImage(for: index)
                    .font(.system(size: starSize))
                    .foregroundStyle(
                        Double(index) <= rating ? .white
                            : Double(index) - 0.5 <= rating ? .white
                            : AppTheme.border
                    )
                    .onTapGesture {
                        let half = Double(index) - 0.5
                        if rating == Double(index) {
                            rating = half
                        } else {
                            rating = Double(index)
                        }
                    }
            }
        }
    }

    private func starImage(for index: Int) -> Image {
        let full = Double(index)
        let half = full - 0.5
        if rating >= full {
            return Image(systemName: "star.fill")
        } else if rating >= half {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
}

struct StarRatingDisplay: View {
    let rating: Double
    var starSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1 ... 5, id: \.self) { index in
                starImage(for: index)
                    .font(.system(size: starSize))
                    .foregroundStyle(
                        Double(index) <= rating ? .white
                            : Double(index) - 0.5 <= rating ? .white
                            : AppTheme.textDim
                    )
            }
        }
    }

    private func starImage(for index: Int) -> Image {
        let full = Double(index)
        let half = full - 0.5
        if rating >= full {
            return Image(systemName: "star.fill")
        } else if rating >= half {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
}
