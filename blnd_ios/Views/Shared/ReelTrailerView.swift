import SwiftUI
import WebKit

/// Autoplay trailer for reels cards with YouTube controls.
struct ReelTrailerView: UIViewRepresentable {
    let videoId: String

    private var embedHTML: String {
        let src = "https://www.youtube-nocookie.com/embed/"
            + "\(videoId)?playsinline=1&rel=0&autoplay=1"
            + "&mute=1&controls=1&showinfo=0&loop=1"
            + "&playlist=\(videoId)&modestbranding=1"
        return """
        <html>
        <head>
        <meta name="viewport" \
        content="width=device-width, initial-scale=1">
        <style>
        * { margin: 0; padding: 0; }
        body { background: #000; }
        .wrap {
            position: relative;
            padding-bottom: 56.25%;
        }
        iframe {
            width: 100%;
            height: 100%;
            position: absolute;
            top: 0; left: 0;
            border: 0;
        }
        </style>
        </head>
        <body>
        <div class="wrap">
        <iframe
            src="\(src)"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen
            allow="autoplay; encrypted-media">
        </iframe>
        </div>
        </body>
        </html>
        """
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(
            frame: .zero,
            configuration: config
        )
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.loadHTMLString(
            embedHTML,
            baseURL: URL(
                string: "https://www.youtube-nocookie.com"
            )
        )
        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {}
}
