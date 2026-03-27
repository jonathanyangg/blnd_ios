import SwiftUI
import WebKit

/// Persistent YouTube player that reuses a single WKWebView across reel cards.
/// Swaps video IDs via JavaScript instead of recreating the WebView each time.
@Observable
final class TrailerPlayer {
    static let shared = TrailerPlayer()

    private(set) var webView: WKWebView
    private(set) var isReady = false
    private(set) var currentVideoId: String?
    private var coordinator: Coordinator?

    private static let embedHost =
        "https://www.youtube-nocookie.com"

    private init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        webView = view

        let coord = Coordinator(player: self)
        coordinator = coord
        view.navigationDelegate = coord

        // Load the YouTube IFrame API once — player starts with no video
        view.loadHTMLString(Self.embedHTML, baseURL: URL(string: Self.embedHost))
    }

    /// Load a new video by ID. If the player is ready, swaps via JS instantly.
    func play(videoId: String) {
        currentVideoId = videoId
        if isReady {
            let script = "loadVideo('\(videoId)');"
            webView.evaluateJavaScript(script)
        }
    }

    /// Stop playback and hide the player
    func stop() {
        currentVideoId = nil
        if isReady {
            webView.evaluateJavaScript("stopVideo();")
        }
    }

    private func markReady() {
        isReady = true
        // If a video was requested before the player was ready, play it now
        if let vid = currentVideoId {
            let script = "loadVideo('\(vid)');"
            webView.evaluateJavaScript(script)
        }
    }

    // MARK: - HTML

    private static var embedHTML: String {
        let host = embedHost
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
        .wrap.hidden { opacity: 0; }
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
                playerVars: {
                    playsinline: 1,
                    autoplay: 0,
                    controls: 0,
                    rel: 0,
                    showinfo: 0,
                    modestbranding: 1,
                    disablekb: 1,
                    iv_load_policy: 3,
                    origin: '\(host)'
                },
                events: {
                    onReady: function() {
                        window.webkit.messageHandlers.playerReady
                            .postMessage('ready');
                    },
                    onStateChange: function(e) {
                        if (e.data === 1) {
                            document.getElementById('wrap')
                                .classList.add('visible');
                            document.getElementById('wrap')
                                .classList.remove('hidden');
                        }
                    }
                }
            });
        }

        function loadVideo(videoId) {
            document.getElementById('wrap')
                .classList.remove('visible');
            document.getElementById('wrap')
                .classList.add('hidden');
            player.loadVideoById({
                videoId: videoId,
                startSeconds: 0
            });
            player.setLoop(true);
        }

        function stopVideo() {
            player.stopVideo();
            document.getElementById('wrap')
                .classList.remove('visible');
            document.getElementById('wrap')
                .classList.add('hidden');
        }
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    private class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var player: TrailerPlayer?

        init(player: TrailerPlayer) {
            self.player = player
            super.init()
            player.webView.configuration.userContentController
                .add(self, name: "playerReady")
        }

        func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "playerReady" {
                player?.markReady()
            }
        }

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

// MARK: - SwiftUI View

/// Wraps the shared TrailerPlayer's WKWebView for display in a reel card.
struct ReelTrailerView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> UIView {
        // Return a container — the actual WebView is added/removed
        UIView()
    }

    func updateUIView(_ container: UIView, context: Context) {
        let player = TrailerPlayer.shared
        let trailerWebView = player.webView

        // Move the shared WebView into this container
        if trailerWebView.superview != container {
            trailerWebView.removeFromSuperview()
            trailerWebView.frame = container.bounds
            trailerWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(trailerWebView)
        }

        // Play the requested video if it changed
        if player.currentVideoId != videoId {
            player.play(videoId: videoId)
        }
    }

    static func dismantleUIView(_ container: UIView, coordinator: ()) {
        // Remove the shared WebView when this view disappears
        let trailerWebView = TrailerPlayer.shared.webView
        if trailerWebView.superview == container {
            TrailerPlayer.shared.stop()
            trailerWebView.removeFromSuperview()
        }
    }
}
