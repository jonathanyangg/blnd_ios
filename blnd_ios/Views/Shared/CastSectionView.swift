import SwiftUI

struct CastSectionView: View {
    let cast: [CastMember]

    var body: some View {
        if !cast.isEmpty {
            Text("Cast")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cast) { member in
                        VStack(spacing: 4) {
                            castAvatar(member)
                            Text(member.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .frame(width: 48)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func castAvatar(_ member: CastMember) -> some View {
        if let path = member.profilePath, let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                default:
                    AvatarView(size: 48)
                }
            }
        } else {
            AvatarView(size: 48)
        }
    }
}
