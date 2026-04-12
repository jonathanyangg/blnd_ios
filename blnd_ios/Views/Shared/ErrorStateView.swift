import SwiftUI

/// Shared error state with icon, message, and retry button.
/// Detects network errors and shows a friendlier "no connection" state.
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.textDim)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            if let retry {
                Button {
                    retry()
                } label: {
                    Text("Retry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var isOffline: Bool {
        let lower = message.lowercased()
        return lower.contains("offline")
            || lower.contains("internet connection")
            || lower.contains("network")
            || lower.contains("not connected")
            || lower.contains("timed out")
    }

    private var icon: String {
        isOffline ? "wifi.slash" : "exclamationmark.triangle"
    }

    private var title: String {
        isOffline ? "No connection" : "Something went wrong"
    }

    private var subtitle: String {
        isOffline
            ? "Check your internet and try again"
            : message
    }
}
