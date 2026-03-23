import SwiftUI

/// 4-state Letterboxd import screen.
struct ImportContextView: View {
    enum ImportViewState {
        case instructions
        case loading
        case results(ImportSummaryResponse)
        case error(String)
    }

    @State var viewState: ImportViewState = .instructions
    @State var showWebView = false
    @State var capturedZipData: Data?
    @State var uploadTask: Task<Void, Never>?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            switch viewState {
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
                    try await ImportAPI.upload(
                        zipData: zipData
                    )
                withAnimation {
                    viewState = .results(summary)
                }
            } catch {
                if !(error is CancellationError) {
                    withAnimation {
                        viewState = .error(
                            "Something went wrong. "
                                + "Please try again."
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImportContextView()
    }
}
