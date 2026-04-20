import SwiftUI

struct BlndPlusBadge: View {
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 1) {
            Text("blnd")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
            Text("+")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(AppTheme.premiumGoldGradient)
        }
    }
}
