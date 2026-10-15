import SwiftUI

struct PosterTile: View {
    let posterPath: String?
    let rating: Double?

    var body: some View {
        // Fit, not fill. A LazyVGrid proposes a huge height, and
        // aspectRatio(fill) stretches the placeholder to that height.
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay { poster }
            .overlay(alignment: .bottomTrailing) { ratingBadge }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var poster: some View {
        if let posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)") {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .posterBlur()
            } placeholder: {
                AppTheme.posterGradient
            }
        } else {
            AppTheme.posterGradient
        }
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if let rating {
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                Text(
                    rating.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0f", rating)
                        : String(format: "%.1f", rating)
                )
                .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(4)
        }
    }
}

#Preview {
    PosterTile(posterPath: nil, rating: 4.5)
        .frame(width: 120)
        .background(AppTheme.background)
}
