import SwiftUI

struct StreamingSheet: View {
    let tmdbId: Int
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var options: [StreamingOption] = []
    @State private var isLoading = true
    @State private var errorMessage: UserFacingError?

    private var streamOptions: [StreamingOption] {
        options.filter(\.isStreamable)
    }

    private var rentOptions: [StreamingOption] {
        options.filter { $0.type == "rent" }
    }

    private var buyOptions: [StreamingOption] {
        options.filter { $0.type == "buy" }
    }

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
            } else if options.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.textDim)
                    Text("Not available for streaming")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                    Text("This movie isn't currently on any streaming services in your region.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                optionsList
            }

            attribution
        }
        .task { await fetchStreaming() }
    }

    // MARK: - Header

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

    // MARK: - Options List

    private var optionsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !streamOptions.isEmpty {
                    section(title: "STREAM", options: streamOptions)
                }
                if !rentOptions.isEmpty {
                    section(title: "RENT", options: rentOptions)
                }
                if !buyOptions.isEmpty {
                    section(title: "BUY", options: buyOptions)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func section(title: String, options: [StreamingOption]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textDim)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            ForEach(options) { option in
                optionRow(option)
            }
        }
    }

    private func optionRow(_ option: StreamingOption) -> some View {
        Button {
            if let url = URL(string: option.link) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                serviceLogo(option.service)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.service.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Text(option.typeLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)

                        if let quality = option.quality?.uppercased() {
                            Text(quality)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textDim)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        if option.expiresSoon {
                            Text("Leaving soon")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.destructive)
                        }
                    }
                }

                Spacer()

                if let price = option.price {
                    Text(price.formatted)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textDim)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func serviceLogo(_ service: StreamingServiceInfo) -> some View {
        let assetName = "streaming_\(service.id)"
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
        } else {
            Text(String(service.name.prefix(1)))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AppTheme.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Attribution

    private var attribution: some View {
        Link(destination: URL(string: "https://www.movieofthenight.com/about/api")!) {
            Text("Powered by Streaming Availability API")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textDim)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Data

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
