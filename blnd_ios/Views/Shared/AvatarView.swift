import SwiftUI

struct AvatarView: View {
    var url: String?
    var size: CGFloat = 40
    var overlap: Bool = false
    var isPremium: Bool = false

    @State private var ringRotation: Double = 0

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
                .stroke(
                    isPremium
                        ? AnyShapeStyle(
                            AngularGradient(
                                colors: [
                                    Color(hex: 0xC49B3D),
                                    Color(hex: 0xF5E6A3),
                                    Color(hex: 0xD4A853),
                                    Color(hex: 0xFFF8E7),
                                    Color(hex: 0xC49B3D),
                                    Color(hex: 0xF5E6A3),
                                    Color(hex: 0xD4A853),
                                    Color(hex: 0xC49B3D),
                                ],
                                center: .center,
                                angle: .degrees(ringRotation)
                            )
                        )
                        : AnyShapeStyle(AppTheme.background),
                    lineWidth: isPremium ? 2.5 : 2
                )
        )
        .padding(.leading, overlap ? -10 : 0)
        .onAppear {
            guard isPremium else { return }
            withAnimation(
                .linear(duration: 3)
                    .repeatForever(autoreverses: false)
            ) {
                ringRotation = 360
            }
        }
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
        AvatarView(size: 80, isPremium: true)
    }
    .padding()
    .background(AppTheme.background)
}
