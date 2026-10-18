import UIKit
import Vision

/// On-device text reading for photo import. Nothing leaves the phone.
enum NotesTextRecognizer {
    /// - Parameter images: Photos or screenshots the user picked.
    /// - Returns: Lines of text, with a blank line between photos.
    static func text(in images: [UIImage]) throws -> String {
        var pages: [String] = []
        for image in images {
            guard let cgImage = image.cgImageForReading() else { continue }
            let page = try recognize(cgImage)
            if !page.isEmpty { pages.append(page) }
        }
        return pages.joined(separator: "\n\n")
    }

    private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

private extension UIImage {
    /// Vision is slow and heavy on a full photo, so long sides are capped.
    func cgImageForReading(maxSide: Int = 1600) -> CGImage? {
        guard let source = cgImage else { return nil }
        let longest = max(source.width, source.height)
        guard longest > maxSide else { return source }
        let scale = CGFloat(maxSide) / CGFloat(longest)
        let size = CGSize(
            width: CGFloat(source.width) * scale,
            height: CGFloat(source.height) * scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: source, scale: 1, orientation: imageOrientation)
                .draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}
