import SwiftUI

/// Full-screen Letterboxd webview container with nav bar,
/// dismiss confirmation, and error alerts.
///
/// Presented as a fullScreenCover. Wraps the reusable WebView
/// component to load the Letterboxd data export page and capture
/// the ZIP download via the onZipCaptured callback.
struct LetterboxdWebView: View {
    let onZipCaptured: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var showDismissConfirm = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var downloadComplete = false

    private let letterboxdURL = URL(
        string: "https://letterboxd.com/settings/data/"
    )!

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ZStack {
                WebView(
                    url: letterboxdURL,
                    onDownloadComplete: { data in
                        downloadComplete = true
                        onZipCaptured(data)
                    },
                    onDownloadFailed: { error in
                        errorMessage = error.localizedDescription
                        showError = true
                    },
                    isLoading: $isLoading,
                    scrollToBottomURLPath: "/settings/data"
                )

                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .background(AppTheme.background)
        .alert(
            "Leave Import?",
            isPresented: $showDismissConfirm
        ) {
            Button("Stay", role: .cancel) {}
            Button("Leave", role: .destructive) {
                dismiss()
            }
        } message: {
            Text(
                "Your Letterboxd login session will be lost."
            )
        }
        .alert(
            "Download Failed",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button {
                if downloadComplete {
                    dismiss()
                } else {
                    showDismissConfirm = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(
                        size: 16,
                        weight: .semibold
                    ))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.cardSecondary)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Import")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            // Invisible placeholder to center the title
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
