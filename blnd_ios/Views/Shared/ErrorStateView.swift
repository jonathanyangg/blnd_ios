import SwiftUI

/// Full-screen empty error. Title, message, and icon come from `UserFacingError` only.
struct ErrorStateView: View {
    let message: UserFacingError
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: message.icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.textDim)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(message.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(message.message)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            if let retry {
                Button("Retry", action: retry)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    .accessibilityIdentifier("state.retry")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("state.error")
    }
}

/// Form and row error. Sits under a field. Retry is optional because the form button often is the retry.
struct InlineError: View {
    let message: UserFacingError
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textDim)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(message.message)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let retry {
                    Button("Retry", action: retry)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Floating error. Same copy as the other two, in the capsule the reels already use.
struct ErrorToast: View {
    let message: UserFacingError
    var retry: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .accessibilityHidden(true)

            Text(message.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            if let retry {
                Button("Retry") {
                    onDismiss?()
                    retry()
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .underline()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.92))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.border, lineWidth: 0.5))
        .onTapGesture { onDismiss?() }
    }
}
