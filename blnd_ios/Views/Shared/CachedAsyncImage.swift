import SwiftUI
import UIKit

/// Drop-in replacement for AsyncImage with URLCache-backed disk + memory caching.
/// Prevents re-downloading the same poster/avatar on every scroll or navigation.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

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
        guard let url, image == nil else { return }
        let request = URLRequest(url: url)
        let data: Data?
        if let cached = ImageCache.shared.session.configuration.urlCache?.cachedResponse(for: request) {
            data = cached.data
        } else {
            do {
                let (downloaded, _) = try await ImageCache.shared.session.data(for: request)
                data = downloaded
            } catch {
                data = nil
            }
        }
        guard let data, !Task.isCancelled else { return }
        // Decode off the main actor so a fast scroll does not hitch on UIImage(data:).
        let decoded = await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: data) else { return nil as UIImage? }
            return image.preparingForDisplay() ?? image
        }.value
        if !Task.isCancelled {
            image = decoded
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
