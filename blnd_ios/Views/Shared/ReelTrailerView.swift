import SwiftUI
import WebKit

/// Autoplay trailer for reels cards using YouTube IFrame Player API.
struct ReelTrailerView: UIViewRepresentable {
    let videoId: String

    private static let embedHost =
        "https://www.youtube-nocookie.com"

    private var embedHTML: String {
        let host = Self.embedHost
        return """
        <html>
        <head>
        <meta name="viewport" \
        content="width=device-width, initial-scale=1">
        <style>
        * { margin: 0; padding: 0; }
        body { background: #000; overflow: hidden; }
        .wrap {
            position: relative;
            width: 100%;
            padding-bottom: 56.25%;
        }
        #player {
            position: absolute;
            top: 0; left: 0;
            width: 100%; height: 100%;
        }
        </style>
        </head>
        <body>
        <div class="wrap">
            <div id="player"></div>
        </div>
        <script>
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        var first = document.getElementsByTagName('script')[0];
        first.parentNode.insertBefore(tag, first);

        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                host: '\(host)',
                videoId: '\(videoId)',
                playerVars: {
                    playsinline: 1,
                    autoplay: 1,
                    controls: 1,
                    rel: 0,
                    showinfo: 0,
                    modestbranding: 1,
                    loop: 1,
                    playlist: '\(videoId)',
                    origin: '\(host)'
                },
                events: {
                    onReady: function(e) {
                        e.target.playVideo();
                    }
                }
            });
        }
        </script>
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
            baseURL: URL(string: Self.embedHost)
        )
        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {}
}
