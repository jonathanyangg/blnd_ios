import SwiftUI

struct ReelToast: View {
    let message: String
    var actionLabel: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .underline()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }
}
