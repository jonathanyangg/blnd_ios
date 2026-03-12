import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
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
            border-radius: 14px;
        }
        </style>
        </head>
        <body>
        <div class="wrap">
        <iframe
            src="https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0"
            allowfullscreen
            allow="autoplay; encrypted-media">
        </iframe>
        </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// Extract YouTube video ID from a full URL
    static func extractVideoId(from url: String) -> String? {
        if let components = URLComponents(string: url) {
            // youtube.com/watch?v=ID
            if let items = components.queryItems, let vid = items.first(where: { $0.name == "v" })?.value {
                return vid
            }
            // youtu.be/ID
            if components.host == "youtu.be" {
                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return path.isEmpty ? nil : path
            }
        }
        return nil
    }
}
