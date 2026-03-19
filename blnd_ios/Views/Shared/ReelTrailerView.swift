import SwiftUI
import WebKit

struct ReelTrailerView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(
            frame: .zero,
            configuration: config
        )
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        let embedURL = "https://www.youtube-nocookie.com/embed/"
            + "\(videoId)?playsinline=1&rel=0&autoplay=1"
            + "&mute=1&controls=0&showinfo=0&loop=1"
            + "&playlist=\(videoId)"
        let html = """
        <html>
        <head>
        <meta name="viewport" \
        content="width=device-width, initial-scale=1">
        <style>
        * { margin: 0; padding: 0; }
        body { background: transparent; overflow: hidden; }
        iframe {
            width: 100vw;
            height: 100vh;
            border: 0;
            pointer-events: none;
        }
        </style>
        </head>
        <body>
        <iframe
            src="\(embedURL)"
            allow="autoplay; encrypted-media"
            allowfullscreen>
        </iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(
            html,
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
