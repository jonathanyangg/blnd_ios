import SwiftUI

struct MovieCard: View {
    var tmdbId: Int?
    var title: String?
    var year: String?
    var posterPath: String?
    var width: CGFloat = 90
    var height: CGFloat = 130
    var glow: Bool = false
    var gradientAngle: Int = 135
    var scorePercent: Int?
    var mediaType: MediaType?

    var isTV: Bool {
        mediaType == .tv
    }

    private var displayTitle: String? {
        guard let title else { return nil }
        if APIConfig.screenshotMode, let tmdbId {
            return ScreenshotDummy.title(for: tmdbId)
        }
        return title
    }

    private var displayYear: String? {
        guard let year else { return nil }
        if APIConfig.screenshotMode, let tmdbId {
            return "\(ScreenshotDummy.year(for: tmdbId))"
        }
        return year
    }

    private var displayScorePercent: Int? {
        if APIConfig.screenshotMode, let tmdbId {
            return ScreenshotDummy.matchPercent(for: tmdbId)
        }
        return scorePercent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster
                .overlay(alignment: .topLeading) {
                    if isTV {
                        Text("TV")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(8)
                            .accessibilityIdentifier("tv-show-badge")
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let displayScorePercent {
                        Text("\(displayScorePercent)%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(8)
                    }
                }
                .shadow(color: glow ? .white.opacity(0.13) : .clear, radius: glow ? 12 : 0)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let displayTitle {
                    Text(displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let displayYear {
                    Text(displayYear)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .frame(width: width, alignment: .leading)
        }
    }

    private var poster: some View {
        Group {
            if APIConfig.screenshotMode {
                placeholder
            } else if let posterPath, let url = posterURL(posterPath) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .posterBlur()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
