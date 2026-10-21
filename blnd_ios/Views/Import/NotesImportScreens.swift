import PhotosUI
import SwiftUI

struct PhotoImportView: View {
    var router: any MovieImportRouting
    @State private var items: [PhotosPickerItem] = []
    @State private var isReading = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Photo or screenshot")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("Pick one or more. We read the words on this phone.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.top, 24)

            PhotosPicker(
                selection: $items,
                maxSelectionCount: 12,
                matching: .images
            ) {
                Text(isReading ? "Reading…" : "Choose photos")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            }
            .accessibilityIdentifier("import.photos.choose")
            .disabled(isReading)

            if isReading {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Reading the text…")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .accessibilityIdentifier("import.photos.reading")
            }

            if let message {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
                    .accessibilityIdentifier("import.photos.message")
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
        .onChange(of: items) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await read(newItems) }
        }
    }

    private func read(_ picked: [PhotosPickerItem]) async {
        isReading = true
        message = nil
        defer { isReading = false }
        do {
            var images: [UIImage] = []
            for item in picked {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }
                images.append(image)
            }
            guard !images.isEmpty else {
                message = "Those photos didn't open. Try different ones."
                return
            }
            let text = try await Task.detached(priority: .userInitiated) {
                try NotesTextRecognizer.text(in: images)
            }.value
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                message = "We couldn't read any words in those photos. Try a clearer screenshot."
                return
            }
            router.open(.notesReview(NotesImportDraft(
                source: .photos,
                text: trimmed,
                imageCount: images.count
            )))
        } catch {
            message = "Those photos didn't open. Try different ones."
        }
    }
}
struct PasteNotesView: View {
    var router: any MovieImportRouting
    @State private var text = ""
    @State private var message: String?

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes or text")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("Paste a list of movies.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.top, 24)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
                    .padding(12)
                    .frame(minHeight: 180)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    .accessibilityIdentifier("import.paste.box")
                if text.isEmpty {
                    Text("One movie on each line")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textDim)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }

            Button {
                if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                    text = pasted
                    message = nil
                } else {
                    message = "Nothing on the clipboard to paste."
                }
            } label: {
                Text("Paste")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.card)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            }
            .accessibilityIdentifier("import.paste.button")

            if let message {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            AppButton(label: "Review", isDisabled: trimmed.isEmpty) {
                router.open(.notesReview(NotesImportDraft(
                    source: .paste,
                    text: trimmed,
                    imageCount: 0
                )))
            }
            .accessibilityIdentifier("import.paste.review")
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
    }
}
