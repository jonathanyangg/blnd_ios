import SwiftUI
import WebKit

/// Autoplay trailer for reels cards using YouTube IFrame Player API.
/// Loads without controls for speed. Stays invisible until playing.
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
            opacity: 0;
            transition: opacity 0.2s ease-in;
        }
        .wrap.visible { opacity: 1; }
        #player {
            position: absolute;
            top: 0; left: 0;
            width: 100%; height: 100%;
        }
        </style>
        </head>
        <body>
        <div class="wrap" id="wrap">
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
                    controls: 0,
                    rel: 0,
                    showinfo: 0,
                    modestbranding: 1,
                    disablekb: 1,
                    iv_load_policy: 3,
                    loop: 1,
                    playlist: '\(videoId)',
                    origin: '\(host)'
                },
                events: {
                    onReady: function(e) {
                        e.target.playVideo();
                    },
                    onStateChange: function(e) {
                        if (e.data === 1) {
                            document.getElementById('wrap')
                                .classList.add('visible');
                        }
                    }
                }
            });
        }
        </script>
        </body>
        </html>
        """
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        webView.navigationDelegate = context.coordinator
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

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (
                WKNavigationActionPolicy
            ) -> Void
        ) {
            guard let url = action.request.url else {
                decisionHandler(.allow)
                return
            }
            let host = url.host ?? ""
            let isYouTubeNav = (
                host.contains("youtube.com")
                    || host.contains("youtu.be")
            ) && !host.contains("youtube-nocookie.com")

            if isYouTubeNav {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
