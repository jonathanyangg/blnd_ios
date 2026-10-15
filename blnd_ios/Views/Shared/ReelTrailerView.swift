import SwiftUI
import WebKit

/// Persistent YouTube player that reuses a single WKWebView across reel cards.
/// Swaps video IDs via JavaScript instead of recreating the WebView each time.
@MainActor
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
        view.uiDelegate = coord

        view.loadHTMLString(Self.embedHTML, baseURL: URL(string: Self.embedHost))
    }

    func play(videoId: String) {
        let sanitized = videoId.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\\", with: "")
        currentVideoId = sanitized
        Analytics.trailerPlayed(videoId: sanitized)
        if isReady {
            webView.evaluateJavaScript("loadVideo('\(sanitized)');")
        }
    }

    func stop() {
        currentVideoId = nil
        if isReady {
            webView.evaluateJavaScript("stopVideo();")
        }
    }

    func pause() {
        if isReady {
            webView.evaluateJavaScript("pauseVideo();")
        }
    }

    func resume() {
        if isReady {
            webView.evaluateJavaScript("resumeVideo();")
        }
    }

    private func markReady() {
        isReady = true
        if let vid = currentVideoId {
            webView.evaluateJavaScript("loadVideo('\(vid)');")
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
        var wantPlaying = false;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                host: '\(host)',
                playerVars: {
                    playsinline: 1,
                    autoplay: 1,
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
                        } else if (e.data === 2 && wantPlaying) {
                            wantPlaying = false;
                            player.playVideo();
                        } else if (e.data === 5 && wantPlaying) {
                            player.playVideo();
                        }
                    },
                    onAutoplayBlocked: function() {
                        player.playVideo();
                    }
                }
            });
        }

        function loadVideo(videoId) {
            document.getElementById('wrap')
                .classList.remove('visible');
            document.getElementById('wrap')
                .classList.add('hidden');
            wantPlaying = true;
            player.loadVideoById({
                videoId: videoId,
                startSeconds: 2.5
            });
            player.setLoop(true);
        }

        function stopVideo() {
            wantPlaying = false;
            player.stopVideo();
            document.getElementById('wrap')
                .classList.remove('visible');
            document.getElementById('wrap')
                .classList.add('hidden');
        }

        function pauseVideo() {
            wantPlaying = false;
            if (player && player.pauseVideo) {
                player.pauseVideo();
            }
        }

        function resumeVideo() {
            wantPlaying = true;
            if (player && player.playVideo) {
                player.playVideo();
            }
        }
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    private class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
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
            createWebViewWith configuration: WKWebViewConfiguration,
            for action: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Only a real tap may leave the app. Embed popups (ads, end screens)
            // were opening Safari on their own and leaving the feed hung.
            if action.navigationType == .linkActivated, let url = action.request.url {
                UIApplication.shared.open(url)
            }
            return nil
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

            if isYouTubeNav, action.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else if isYouTubeNav {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - SwiftUI View

struct ReelTrailerView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ container: UIView, context: Context) {
        let trailerWebView = TrailerPlayer.shared.webView

        trailerWebView.isUserInteractionEnabled = false
        if trailerWebView.superview != container {
            trailerWebView.removeFromSuperview()
            trailerWebView.frame = container.bounds
            trailerWebView.autoresizingMask = [
                .flexibleWidth, .flexibleHeight,
            ]
            container.addSubview(trailerWebView)
        }
    }

    static func dismantleUIView(
        _ container: UIView, coordinator: ()
    ) {
        let trailerWebView = TrailerPlayer.shared.webView
        if trailerWebView.superview == container {
            TrailerPlayer.shared.stop()
            trailerWebView.removeFromSuperview()
        }
    }
}
