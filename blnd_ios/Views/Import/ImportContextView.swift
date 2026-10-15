import SwiftUI

/// Letterboxd import screen. Onboarding starts it at `.question`.
struct ImportContextView: View {
    enum ImportViewState {
        case question
        case instructions
        case loading
        case results(ImportSummaryResponse)
        case error(UserFacingError)
    }

    @State var viewState: ImportViewState = .instructions
    @State var showWebView = false
    @State var capturedZipData: Data?
    @State var uploadTask: Task<Void, Never>?
    var onComplete: (() -> Void)?
    var onSkip: (() -> Void)?
    var importHandler: ((Data) async throws -> ImportSummaryResponse)?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            switch viewState {
            case .question:
                questionContent
            case .instructions:
                instructionsContent
            case .loading:
                loadingContent
            case let .results(summary):
                resultsContent(summary: summary)
            case let .error(message):
                errorContent(message: message)
            }
        }
        .animation(
            .easeInOut(duration: 0.3), value: stateKey
        )
        .fullScreenCover(isPresented: $showWebView) {
            LetterboxdWebView { data in
                capturedZipData = data
                showWebView = false
            }
        }
        .onChange(of: capturedZipData) { oldVal, newVal in
            if oldVal == nil, newVal != nil {
                startUpload()
            }
        }
        .onDisappear {
            uploadTask?.cancel()
        }
    }

    var stateKey: String {
        switch viewState {
        case .question: return "question"
        case .instructions: return "instructions"
        case .loading: return "loading"
        case .results: return "results"
        case .error: return "error"
        }
    }

    func startUpload() {
        withAnimation { viewState = .loading }

        uploadTask = Task {
            guard let zipData = capturedZipData
            else { return }
            do {
                let summary =
                    try await uploadImport(zipData: zipData)
                withAnimation {
                    viewState = .results(summary)
                }
            } catch {
                if !(error is CancellationError) {
                    withAnimation {
                        viewState = .error(
                            UserFacingError.capture(error, screen: "LetterboxdImport")
                        )
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

    func answerUsesLetterboxd(_ usesLetterboxd: Bool) {
        if usesLetterboxd {
            withAnimation { viewState = .instructions }
        } else {
            onSkip?()
        }
    }

    func finish() {
        if let onComplete {
            onComplete()
        } else {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ImportContextView()
    }
}
