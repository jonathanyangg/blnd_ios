import SwiftUI

/// Rent, Buy, and Watch now for one movie or series.
struct WhereToWatchSection: View {
    let options: [StreamingOption]
    var isLoading: Bool
    var failed: Bool
    var isPremium: Bool
    var showsTitle: Bool = true
    var onOpen: (StreamingOption) -> Void

    private let justWatchURL = URL(string: "https://www.justwatch.com")!

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle {
                Text("Where to watch")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("whereToWatch")
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if failed {
                Text("Couldn't load where to watch")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
            } else if !hasRows {
                Text("Not available in your region.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                attribution
            } else {
                rows
                if WhereToWatchList.showsAffiliatePrompt(
                    isPremium: isPremium,
                    options: options
                ) {
                    Text("Includes affiliate links")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textDim)
                        .accessibilityIdentifier("affiliatePrompt")
                }
                attribution
            }
        }
        .padding(.bottom, 20)
    }

    private var hasRows: Bool {
        WatchOfferKind.allCases.contains { kind in
            !WhereToWatchList.offers(from: options, kind: kind).isEmpty
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(WatchOfferKind.allCases, id: \.self) { kind in
                let offers = WhereToWatchList.offers(from: options, kind: kind)
                ForEach(offers) { option in
                    offerButton(option, kind: kind)
                }
            }
        }
    }

    private func offerButton(
        _ option: StreamingOption,
        kind: WatchOfferKind
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpen(option)
        } label: {
            HStack(spacing: 12) {
                serviceLogo(option.service)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.service.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    if let price = option.price?.formatted, !price.isEmpty {
                        Text(price)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                Spacer(minLength: 8)
                Text(kind.buttonTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.buttonTitle) on \(option.service.name)")
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

    private var attribution: some View {
        Link(destination: justWatchURL) {
            Text("Data provided by JustWatch")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textDim)
        }
        .accessibilityIdentifier("justWatchAttribution")
    }
}
