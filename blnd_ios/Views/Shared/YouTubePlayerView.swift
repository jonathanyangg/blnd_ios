import SwiftUI
import WebKit

struct YouTubePlayerView: View {
    let videoId: String
    let backdropPath: String?

    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if isPlaying {
                YouTubeWebView(videoId: videoId)
            } else {
                thumbnail
                    .onTapGesture { isPlaying = true }
            }
        }
    }

    private var thumbnail: some View {
        ZStack {
            if let backdrop = backdropPath {
                CachedAsyncImage(
                    url: URL(string: "https://image.tmdb.org/t/p/w780\(backdrop)")
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .posterBlur()
                } placeholder: {
                    Color.black
                }
            } else {
                Color.black
            }

            Circle()
                .fill(.black.opacity(0.5))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                )
        }
    }

    /// Extract YouTube video ID from a full URL
    static func extractVideoId(from url: String) -> String? {
        if let components = URLComponents(string: url) {
            // youtube.com/watch?v=ID
            if let items = components.queryItems, let vid = items.first(where: { $0.name == "v" })?.value {
                return vid
            }
            // youtu.be/ID
            if components.host == "youtu.be" {
                let path = components.path.trimmingCharacters(
                    in: CharacterSet(charactersIn: "/")
                )
                return path.isEmpty ? nil : path
            }
        }
        return nil
    }
}

private struct YouTubeWebView: UIViewRepresentable {
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

        let nocookie = "https://www.youtube-nocookie.com"
        let embedURL = "\(nocookie)/embed/\(videoId)"
            + "?playsinline=1&rel=0&autoplay=1"
            + "&origin=\(nocookie)"
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
            src="\(embedURL)"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen
            allow="autoplay; encrypted-media">
        </iframe>
        </div>
        </body>
        </html>
        """
        webView.loadHTMLString(
            html,
            baseURL: URL(string: "https://www.youtube-nocookie.com")
        )

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
