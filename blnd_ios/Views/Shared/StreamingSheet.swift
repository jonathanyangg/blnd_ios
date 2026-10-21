import SwiftUI

struct StreamingSheet: View {
    let tmdbId: Int
    let title: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState
    @State private var options: [StreamingOption] = []
    @State private var isLoading = true
    @State private var errorMessage: UserFacingError?

    var body: some View {
        VStack(spacing: 0) {
            header
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                ErrorStateView(message: error) {
                    Task { await fetchStreaming() }
                }
                Spacer()
            } else {
                ScrollView {
                    WhereToWatchSection(
                        options: options,
                        isLoading: false,
                        failed: false,
                        isPremium: authState.isPremium,
                        showsTitle: false
                    ) { offer in
                        Task { await WatchLinkOpener.open(offer) }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .task { await fetchStreaming() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.background)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Where to Watch")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func fetchStreaming() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await MoviesAPI.getStreaming(tmdbId: tmdbId)
            options = response.options
        } catch is CancellationError {
            // View dismissed before load finished
        } catch {
            errorMessage = UserFacingError.capture(error, screen: "Streaming")
        }
        isLoading = false
    }
}
