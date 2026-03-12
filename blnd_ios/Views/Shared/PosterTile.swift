import SwiftUI

struct PosterTile: View {
    let posterPath: String?
    let rating: Double?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(2 / 3, contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.posterGradient)
                            .aspectRatio(2 / 3, contentMode: .fill)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.posterGradient)
                    .aspectRatio(2 / 3, contentMode: .fill)
            }

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
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
                .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PosterTile(posterPath: nil, rating: 4.5)
        .frame(width: 120)
        .background(AppTheme.background)
}
