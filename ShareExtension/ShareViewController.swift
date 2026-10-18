import UIKit
import UniformTypeIdentifiers

/// Share sheet entry for a note. Saves the text, then opens blnd.
class ShareViewController: UIViewController {
    private let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        status.textColor = .white
        status.font = .systemFont(ofSize: 17, weight: .semibold)
        status.textAlignment = .center
        status.text = "Opening blnd…"
        status.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(status)
        NSLayoutConstraint.activate([
            status.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            status.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            status.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
        Task { await capture() }
    }

    private func capture() async {
        guard let text = await capturedText() else {
            status.text = "Nothing to import"
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        NotesShareText.save(text)
        guard let context = extensionContext else { return }
        context.open(NotesShareText.openURL) { _ in
            context.completeRequest(returningItems: nil)
        }
    }

    private func capturedText() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        var parts: [String] = []
        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await loadText(from: provider) {
                    parts.append(text)
                }
            }
        }
        return NotesShareText.joined(parts)
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        let types = [UTType.plainText.identifier, UTType.utf8PlainText.identifier, UTType.text.identifier]
        for type in types where provider.hasItemConformingToTypeIdentifier(type) {
            guard let item = try? await provider.loadItem(forTypeIdentifier: type) else { continue }
            if let text = item as? String { return text }
            if let text = item as? NSString { return text as String }
            if let data = item as? Data, let text = String(data: data, encoding: .utf8) { return text }
            if let url = item as? URL, url.isFileURL,
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
            }
        }
        return nil
    }
}
