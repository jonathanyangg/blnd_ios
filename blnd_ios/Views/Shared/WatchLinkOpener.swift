import UIKit

/// Opens a where-to-watch offer in Safari or the provider's app.
///
/// Amazon rejects affiliate traffic from in-app browsers, so this never uses
/// `SFSafariViewController` or `WKWebView`. Watch now tries `ios_link` first
/// (universal link, or the `aiv` scheme). Rent and buy open `click_url`, then
/// `web_url`. The client does not add a tag.
enum WatchLinkOpener {
    @MainActor
    static func open(_ offer: WatchOffer, kind: WatchOfferKind) async {
        guard let plan = offer.openPlan(kind: kind) else { return }
        if let appLink = plan.appLink {
            let opened = await UIApplication.shared.open(
                appLink,
                options: [.universalLinksOnly: true]
            )
            if opened { return }
        }
        if let schemeLink = plan.schemeLink,
           UIApplication.shared.canOpenURL(schemeLink) {
            let opened = await UIApplication.shared.open(schemeLink)
            if opened { return }
        }
        await UIApplication.shared.open(plan.webLink)
    }
}
