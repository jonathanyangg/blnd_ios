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
                    HStack(spacing: 10) {
                        ForEach(
                            Array(cast.enumerated()),
                            id: \.offset
                        ) { _, member in
                            VStack(spacing: 3) {
                                castAvatar(member)
                                Text(member.name)
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        AppTheme.textMuted
                                    )
                                    .lineLimit(1)
                                    .frame(width: 36)
                            }
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
        if let path = member.profilePath, let url = URL(string: "\(base)\(path)") {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .posterBlur()
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(AppTheme.card)
                    .frame(width: 36, height: 36)
            }
        } else {
            Circle()
                .fill(AppTheme.card)
                .frame(width: 36, height: 36)
        }
    }
}
