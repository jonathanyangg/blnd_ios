import SwiftUI
import UIKit

/// Drop-in replacement for AsyncImage with URLCache-backed disk + memory caching.
/// Prevents re-downloading the same poster/avatar on every scroll or navigation.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) { await loadImage() }
            }
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let request = URLRequest(url: url)

        // Check cache first
        if let cached = ImageCache.shared.session.configuration.urlCache?.cachedResponse(for: request) {
            image = UIImage(data: cached.data)
            return
        }

        // Fetch from network
        do {
            let (data, _) = try await ImageCache.shared.session.data(for: request)
            if !Task.isCancelled {
                image = UIImage(data: data)
            }
        } catch {
            // Silently fail — placeholder stays visible
        }
    }
}

/// Shared URLSession with a large URLCache for image downloads.
enum ImageCache {
    static let shared: (session: URLSession, cache: URLCache) = {
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50 MB memory
            diskCapacity: 200 * 1024 * 1024 // 200 MB disk
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)
        return (session, cache)
    }()
}
