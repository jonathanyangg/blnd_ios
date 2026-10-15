import SwiftUI
import UniformTypeIdentifiers

/// Letterboxd export-and-upload steps. The movie hub opens this.
struct ImportContextView: View {
    enum ImportViewState {
        case instructions
        case loading
        case results(ImportSummaryResponse)
        case fileError(String)
        case error(String)
    }

    @State var viewState: ImportViewState
    @State var showFileImporter = false
    @State var zipData: Data?
    @State var importedRatings: Int
    @State var uploadTask: Task<Void, Never>?
    var onComplete: (() -> Void)?
    var onSkip: (() -> Void)?
    var importHandler: ((Data) async throws -> ImportSummaryResponse)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    static let importTypes: [UTType] = {
        var types: [UTType] = [.zip, .commaSeparatedText, .plainText, .data]
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        return types
    }()

    init(
        viewState: ImportViewState = .instructions,
        onComplete: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil,
        importHandler: ((Data) async throws -> ImportSummaryResponse)? = nil
    ) {
        let preview = Self.previewState(fallback: viewState)
        _viewState = State(initialValue: preview.state)
        _importedRatings = State(initialValue: preview.ratings)
        self.onComplete = onComplete
        self.onSkip = onSkip
        self.importHandler = importHandler
    }

    var body: some View {
        Group {
            switch viewState {
            case .instructions:
                instructionsContent
            case .loading:
                loadingContent
            case let .results(summary):
                resultsContent(summary: summary)
            case let .fileError(message):
                fileErrorContent(message: message)
            case let .error(message):
                errorContent(message: message)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stateKey)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: Self.importTypes,
            onCompletion: handlePickedFile
        )
        .onDisappear { uploadTask?.cancel() }
    }

    var stateKey: String {
        switch viewState {
        case .instructions: return "instructions"
        case .loading: return "loading"
        case .results: return "results"
        case .fileError: return "fileError"
        case .error: return "error"
        }
    }

    func openLetterboxdExportPage() {
        openURL(LetterboxdExport.pageURL)
    }

    func handlePickedFile(_ result: Result<URL, Error>) {
        switch result {
        case let .failure(error):
            guard !isCancellation(error) else { return }
            withAnimation { viewState = .fileError(LetterboxdExportError.unreadable.message) }
        case let .success(url):
            readPickedFile(url)
        }
    }

    func readPickedFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let prepared = try LetterboxdExport.prepare(data: data, filename: url.lastPathComponent)
            importedRatings = prepared.ratingsCount
            zipData = prepared.zipData
            startUpload()
        } catch let error as LetterboxdExportError {
            withAnimation { viewState = .fileError(error.message) }
        } catch {
            withAnimation { viewState = .fileError(LetterboxdExportError.unreadable.message) }
        }
    }

    func startUpload() {
        withAnimation { viewState = .loading }
        uploadTask = Task {
            guard let zipData else { return }
            do {
                let summary = try await uploadImport(zipData: zipData)
                withAnimation { viewState = .results(summary) }
            } catch {
                if !(error is CancellationError) {
                    withAnimation {
                        viewState = .error("Something went wrong. Please try again.")
                    }
                }
            }
        }
    }

    func uploadImport(zipData: Data) async throws -> ImportSummaryResponse {
        if let importHandler {
            return try await importHandler(zipData)
        }
        return try await ImportAPI.upload(zipData: zipData)
    }

    func skipForNow() {
        if let onSkip {
            onSkip()
        } else {
            dismiss()
        }
    }

    func chooseAnotherFile() {
        zipData = nil
        withAnimation { viewState = .instructions }
        showFileImporter = true
    }

    func finish() {
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }

    func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }

    /// Screenshot launches pass one of these arguments. A normal launch is unchanged.
    static func previewState(fallback: ImportViewState) -> (state: ImportViewState, ratings: Int) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("UI_TEST_LETTERBOXD_PROGRESS") {
            return (.loading, 0)
        }
        if arguments.contains("UI_TEST_LETTERBOXD_SUCCESS") {
            let summary = ImportSummaryResponse(
                imported: 12,
                skipped: 1,
                failed: 0,
                failedTitles: []
            )
            return (.results(summary), 9)
        }
        if arguments.contains("UI_TEST_LETTERBOXD_WRONG_FILE") {
            return (.fileError(LetterboxdExportError.wrongFile.message), 0)
        }
        #endif
        return (fallback, 0)
    }
}

#Preview {
    NavigationStack {
        ImportContextView()
    }
}
