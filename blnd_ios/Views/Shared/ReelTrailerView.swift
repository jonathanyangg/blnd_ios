import AVFoundation
import Observation
import SwiftUI
import WebKit

/// The one reel trailer player. A licensed native clip plays in `nativePlayer`;
/// otherwise a single reused WKWebView swaps YouTube embed video IDs via JavaScript.
@MainActor
@Observable
final class TrailerPlayer {
    static let shared = TrailerPlayer()

    @ObservationIgnored private(set) var webView: WKWebView
    @ObservationIgnored private(set) var isReady = false
    @ObservationIgnored private(set) var currentVideoId: String?
    @ObservationIgnored private var coordinator: Coordinator?
    /// True once the active source reports frames, so the poster can stay up until then.
    private(set) var isPlaying = false
    private(set) var isMuted = true
    let nativePlayer = AVQueuePlayer()
    @ObservationIgnored private var looper: AVPlayerLooper?
    @ObservationIgnored private var warmAsset: AVURLAsset?
    @ObservationIgnored private var nativeStatus: NSKeyValueObservation?

    private static let embedHost = YouTubeEmbed.host

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
        nativePlayer.isMuted = true
        nativeStatus = nativePlayer.observe(\.timeControlStatus) { player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor in TrailerPlayer.shared.isPlaying = playing }
        }
    }

    /// Plays a licensed clip (iTunes preview) muted and looping.
    func playNative(url: URL) {
        stop()
        let asset = warmAsset?.url == url ? warmAsset! : AVURLAsset(url: url)
        looper = AVPlayerLooper(player: nativePlayer, templateItem: AVPlayerItem(asset: asset))
        nativePlayer.isMuted = isMuted
        nativePlayer.play()
    }

    /// Warms up the next reel's clip: metadata only, never the whole file.
    func preload(url: URL) {
        guard warmAsset?.url != url else { return }
        let asset = AVURLAsset(url: url)
        warmAsset = asset
        Task { _ = try? await asset.load(.isPlayable) }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        nativePlayer.isMuted = muted
        if isReady {
            webView.evaluateJavaScript("setMuted(\(muted));")
        }
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
        isPlaying = false
        looper?.disableLooping()
        looper = nil
        nativePlayer.pause()
        nativePlayer.removeAllItems()
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
        webView.evaluateJavaScript("setMuted(\(isMuted));")
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
        html, body { height: 100%; background: #000; overflow: hidden; }
        .wrap {
            position: absolute;
            top: 50%; left: 50%;
            width: max(100vw, 177.78vh);
            height: max(100vh, 56.25vw);
            transform: translate(-50%, -50%);
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
                playerVars: \(YouTubeEmbed.playerVarsJS),
                events: {
                    onReady: function() {
                        window.webkit.messageHandlers.playerReady
                            .postMessage('ready');
                    },
                    onStateChange: function(e) {
                        window.webkit.messageHandlers.playerState
                            .postMessage(e.data);
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
            setMuted(muted);
        }

        var muted = true;
        function setMuted(m) {
            muted = m;
            if (!player || !player.mute) { return; }
            if (m) { player.mute(); } else { player.unMute(); }
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
            player.webView.configuration.userContentController
                .add(self, name: "playerState")
        }

        func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "playerReady" {
                player?.markReady()
            } else if message.name == "playerState", player?.currentVideoId != nil {
                player?.isPlaying = (message.body as? Int) == 1
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

/// Full-bleed AVPlayerLayer for licensed native clips.
struct NativeTrailerView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.isUserInteractionEnabled = false
        (view.layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        (view.layer as? AVPlayerLayer)?.player = player
    }
}

/// UIKit long press so "began" and "released" are reliable inside the paging ScrollView.
struct ReelHoldGesture: UIGestureRecognizerRepresentable {
    var onBegan: () -> Void
    var onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.25
        recognizer.allowableMovement = 12
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began: onBegan()
        case .ended, .cancelled, .failed: onEnded()
        default: break
        }
    }
}
