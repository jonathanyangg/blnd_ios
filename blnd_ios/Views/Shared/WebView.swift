import SwiftUI
import WebKit

/// Reusable UIViewRepresentable wrapping WKWebView with download interception.
///
/// Loads a URL in a WKWebView and intercepts file downloads via
/// WKNavigationDelegate and WKDownloadDelegate, returning the
/// downloaded file as in-memory Data.
struct WebView: UIViewRepresentable {
    let url: URL
    let onDownloadComplete: (Data) -> Void
    let onDownloadFailed: (Error) -> Void
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDownloadComplete: onDownloadComplete,
            onDownloadFailed: onDownloadFailed,
            isLoading: $isLoading
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Use default (persistent) data store so cookies persist
        // during the session (required for Letterboxd login)
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Store strong reference so Coordinator is not deallocated
        context.coordinator.webView = webView

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    // MARK: - Coordinator

    /// Coordinator serving as both WKNavigationDelegate and
    /// WKDownloadDelegate to detect and capture file downloads.
    class Coordinator: NSObject, WKNavigationDelegate,
        WKDownloadDelegate
    {
        let onDownloadComplete: (Data) -> Void
        let onDownloadFailed: (Error) -> Void
        var isLoading: Binding<Bool>
        private var fileDestinationURL: URL?
        // Strong reference to prevent WKDownload deallocation
        private var currentDownload: WKDownload?
        weak var webView: WKWebView?

        private static let downloadableMIMETypes: Set<String> = [
            "application/zip",
            "application/octet-stream",
            "application/x-zip-compressed",
            "application/x-zip",
        ]

        init(
            onDownloadComplete: @escaping (Data) -> Void,
            onDownloadFailed: @escaping (Error) -> Void,
            isLoading: Binding<Bool>
        ) {
            self.onDownloadComplete = onDownloadComplete
            self.onDownloadFailed = onDownloadFailed
            self.isLoading = isLoading
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _: WKWebView,
            didStartProvisionalNavigation _: WKNavigation!
        ) {
            isLoading.wrappedValue = true
        }

        func webView(
            _: WKWebView,
            didFinish _: WKNavigation!
        ) {
            isLoading.wrappedValue = false
        }

        func webView(
            _: WKWebView,
            didFail _: WKNavigation!,
            withError _: any Error
        ) {
            isLoading.wrappedValue = false
        }

        func webView(
            _: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (
                WKNavigationResponsePolicy
            ) -> Void
        ) {
            if isDownloadableResponse(navigationResponse) {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (
                WKNavigationActionPolicy
            ) -> Void
        ) {
            if let url = navigationAction.request.url,
               isDownloadableURL(url)
            {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _: WKWebView,
            navigationResponse _: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            download.delegate = self
            currentDownload = download
        }

        func webView(
            _: WKWebView,
            navigationAction _: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            download.delegate = self
            currentDownload = download
        }

        // MARK: - WKDownloadDelegate

        func download(
            _: WKDownload,
            decideDestinationUsing _: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(
                suggestedFilename
            )
            // Remove existing file to avoid conflict on retry
            try? FileManager.default.removeItem(at: fileURL)
            fileDestinationURL = fileURL
            completionHandler(fileURL)
        }

        func downloadDidFinish(_: WKDownload) {
            guard let url = fileDestinationURL else { return }
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async { [weak self] in
                    self?.onDownloadComplete(data)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.onDownloadFailed(error)
                }
            }
            currentDownload = nil
        }

        func download(
            _: WKDownload,
            didFailWithError error: any Error,
            resumeData _: Data?
        ) {
            DispatchQueue.main.async { [weak self] in
                self?.onDownloadFailed(error)
            }
            currentDownload = nil
        }

        // MARK: - Private Helpers

        private func isDownloadableResponse(
            _ response: WKNavigationResponse
        ) -> Bool {
            if let mimeType = response.response.mimeType,
               Self.downloadableMIMETypes.contains(
                   mimeType.lowercased()
               )
            {
                return true
            }

            if let url = response.response.url,
               url.pathExtension.lowercased() == "zip"
            {
                return true
            }

            // Check Content-Disposition header for "attachment"
            if let httpResponse = response.response
                as? HTTPURLResponse,
                let disposition = httpResponse.value(
                    forHTTPHeaderField: "Content-Disposition"
                ),
                disposition.lowercased().contains("attachment")
            {
                return true
            }

            return false
        }

        private func isDownloadableURL(_ url: URL) -> Bool {
            let path = url.path.lowercased()
            return path.contains("export")
                && url.pathExtension.lowercased() == "zip"
        }
    }
}
