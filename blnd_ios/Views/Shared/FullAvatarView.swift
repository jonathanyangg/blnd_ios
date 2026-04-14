import SwiftUI

/// Fullscreen avatar overlay — tap the X or background to dismiss.
struct FullAvatarView: View {
    let url: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack {
                HStack {
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.card)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                Spacer()
            }

            if let url, let imageURL = URL(string: url) {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Circle())
                        .padding(40)
                } placeholder: {
                    AvatarView(size: 200)
                }
            } else {
                AvatarView(size: 200)
            }
        }
    }
}
