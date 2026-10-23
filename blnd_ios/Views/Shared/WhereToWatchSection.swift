import SwiftUI

/// Rent, Buy, and Watch now for one movie or series.
struct WhereToWatchSection: View {
    let payload: WhereToWatch?
    var isLoading: Bool
    var failed: Bool
    var isPremium: Bool
    var showsTitle: Bool = true
    var onOpen: (WatchOffer, WatchOfferKind) -> Void

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
            } else if failed || payload == nil {
                Text("Couldn't load where to watch")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
            } else if let payload, !payload.hasOffers {
                Text("Not available in your region.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                attribution(payload)
            } else if let payload {
                rows(payload)
                if payload.showsAffiliatePrompt(isPremium: isPremium) {
                    Text("Includes affiliate links")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textDim)
                        .accessibilityIdentifier("affiliatePrompt")
                }
                attribution(payload)
            }
        }
        .padding(.bottom, 20)
    }

    private func rows(_ payload: WhereToWatch) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(WatchOfferKind.allCases, id: \.self) { kind in
                ForEach(payload.offers(kind)) { offer in
                    offerButton(offer, kind: kind)
                }
            }
        }
    }

    private func offerButton(_ offer: WatchOffer, kind: WatchOfferKind) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpen(offer, kind)
        } label: {
            HStack(spacing: 12) {
                serviceLogo(offer)
                Text(offer.providerName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
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
        .accessibilityLabel("\(kind.buttonTitle) on \(offer.providerName)")
    }

    @ViewBuilder
    private func serviceLogo(_ offer: WatchOffer) -> some View {
        let letter = Text(String(offer.providerName.prefix(1)))
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(AppTheme.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        if let url = offer.logoURL {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                letter
            }
        } else {
            letter
        }
    }

    private func attribution(_ payload: WhereToWatch) -> some View {
        Link(destination: payload.attributionURL) {
            Text("Data provided by \(payload.attribution)")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textDim)
        }
        .accessibilityIdentifier("justWatchAttribution")
    }
}
