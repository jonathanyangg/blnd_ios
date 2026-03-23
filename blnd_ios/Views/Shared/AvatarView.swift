import SwiftUI

struct AvatarView: View {
    var url: String?
    var size: CGFloat = 40
    var overlap: Bool = false

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    gradientCircle
                }
            } else {
                gradientCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.background, lineWidth: 2)
        )
        .padding(.leading, overlap ? -10 : 0)
    }

    private var gradientCircle: some View {
        Circle()
            .fill(AppTheme.avatarGradient)
    }
}

#Preview {
    HStack(spacing: 0) {
        AvatarView()
        AvatarView(overlap: true)
        AvatarView(overlap: true)
    }
    .padding()
    .background(AppTheme.background)
}
