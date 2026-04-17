import SwiftUI

struct CastSectionView: View {
    let cast: [CastMember]

    var body: some View {
        if !cast.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cast")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                ScrollView(
                    .horizontal, showsIndicators: false
                ) {
                    HStack(spacing: 12) {
                        ForEach(
                            Array(cast.enumerated()),
                            id: \.element.stableId
                        ) { idx, member in
                            NavigationLink {
                                ActorProfileView(
                                    personId: member.id,
                                    name: member.name,
                                    profilePath: member.profilePath
                                )
                            } label: {
                                VStack(spacing: 3) {
                                    castAvatar(member)
                                    Text(
                                        APIConfig.screenshotMode
                                            ? ScreenshotDummy.castName(at: idx)
                                            : member.name
                                    )
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        AppTheme.textMuted
                                    )
                                    .lineLimit(1)
                                    .frame(width: 36)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func castAvatar(
        _ member: CastMember
    ) -> some View {
        let base = "https://image.tmdb.org/t/p/w185"
        Group {
            if let path = member.profilePath, let url = URL(string: "\(base)\(path)") {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.card)
                }
            } else {
                Circle()
                    .fill(AppTheme.card)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }
}
