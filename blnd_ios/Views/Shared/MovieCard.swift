import SwiftUI

struct MovieCard: View {
    var title: String?
    var year: String?
    var posterPath: String?
    var width: CGFloat = 90
    var height: CGFloat = 130
    var glow: Bool = false
    var gradientAngle: Int = 135
    var scorePercent: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottom) {
                if let posterPath, let url = posterURL(posterPath) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: height)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }

                // Bottom gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(width: width, height: height)
            }
            .overlay(alignment: .topTrailing) {
                if let scorePercent {
                    Text("\(scorePercent)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .shadow(color: glow ? .white.opacity(0.13) : .clear, radius: glow ? 12 : 0)

            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }

            if let year {
                Text(year)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(AppTheme.posterGradient(angle: gradientAngle))
            .frame(width: width, height: height)
    }

    private func posterURL(_ path: String) -> URL? {
        URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }
}

#Preview {
    HStack(spacing: 10) {
        MovieCard(title: "Dune", year: "2021")
        MovieCard(title: "Arrival", year: "2016", glow: true)
        MovieCard()
    }
    .padding()
    .background(AppTheme.background)
}
