import SwiftUI

/// 4-state Letterboxd import screen.
///
/// States:
/// - **instructions**: Pre-webview steps + Continue button
/// - **loading**: Spinner while ZIP uploads to backend
/// - **results**: Import summary (imported/skipped/failed counts)
/// - **error**: Upload failure with retry and back options
///
/// Pushed onto ProfileView's NavigationStack. After the webview delivers ZIP data,
/// upload begins automatically via `.onChange(of: capturedZipData)`.
struct ImportContextView: View {
    // MARK: - State machine

    private enum ImportViewState {
        case instructions
        case loading
        case results(ImportSummaryResponse)
        case error(String)
    }

    @State private var viewState: ImportViewState = .instructions
    @State private var showWebView = false
    @State private var capturedZipData: Data?
    @State private var uploadTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

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
        .animation(.easeInOut(duration: 0.3), value: stateKey)
        .fullScreenCover(isPresented: $showWebView) {
            LetterboxdWebView { data in
                capturedZipData = data
                showWebView = false
            }
        }
        .onChange(of: capturedZipData) { oldValue, newValue in
            if oldValue == nil, newValue != nil {
                startUpload()
            }
        }
        .onDisappear {
            uploadTask?.cancel()
        }
    }

    // MARK: - State key (drives animation)

    private var stateKey: String {
        switch viewState {
        case .instructions: return "instructions"
        case .loading: return "loading"
        case .results: return "results"
        case .error: return "error"
        }
    }

    // MARK: - Instructions state

    private var instructionsContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    brandingHeader
                    instructionsCard
                    Spacer(minLength: 40)
                }
            }

            AppButton(label: "Continue") {
                showWebView = true
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden(false)
    }

    // MARK: - Loading state

    private var loadingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "film.stack")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(.white)

                Text("Importing your movies...")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .transition(.opacity)
    }

    // MARK: - Results state

    private func resultsContent(summary: ImportSummaryResponse) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                        .padding(.top, 60)

                    Text("Import Complete")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    // Hero number
                    VStack(spacing: 4) {
                        Text("\(summary.imported)")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(.white)

                        Text("movies imported")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    // Conditional stat rows
                    VStack(spacing: 8) {
                        if summary.skipped > 0 {
                            statRow(count: summary.skipped, label: "skipped")
                        }
                        if summary.failed > 0 {
                            statRow(count: summary.failed, label: "failed")
                        }
                    }

                    // Failed titles list
                    if summary.failed > 0, !summary.failedTitles.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(summary.failedTitles, id: \.self) { title in
                                    Text(title)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(16)
                        }
                        .frame(maxHeight: 200)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }

            AppButton(label: "Done") {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(AppTheme.background)
        .transition(.opacity)
    }

    // MARK: - Error state

    private func errorContent(message: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)

                Text("Import Failed")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            HStack(spacing: 12) {
                AppButton(label: "Back", style: .ghost) {
                    withAnimation {
                        viewState = .instructions
                        capturedZipData = nil
                    }
                }

                AppButton(label: "Try Again") {
                    startUpload()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .transition(.opacity)
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 50))
                .foregroundStyle(.white)

            Text("Letterboxd Import")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 60)
        .padding(.bottom, 32)
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(spacing: 16) {
            stepRow(number: 1, text: "Log in to your Letterboxd account")
            stepRow(number: 2, text: "Scroll to the bottom")
            stepRow(number: 3, text: "Tap \"Export Your Data\"")
            stepRow(number: 4, text: "We'll handle the rest")
        }
        .padding(20)
        .background(AppTheme.card)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppTheme.cornerRadiusMedium
            )
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Row helpers

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.cardSecondary)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private func statRow(count: Int, label: String) -> some View {
        Text("\(count) \(label)")
            .font(.system(size: 16))
            .foregroundStyle(AppTheme.textMuted)
    }

    // MARK: - Upload

    private func startUpload() {
        withAnimation { viewState = .loading }

        uploadTask = Task {
            guard let zipData = capturedZipData else { return }
            do {
                let summary = try await ImportAPI.upload(zipData: zipData)
                withAnimation { viewState = .results(summary) }
            } catch {
                if !(error is CancellationError) {
                    print("[Import] Upload failed: \(error)")
                    withAnimation { viewState = .error("Something went wrong. Please try again.") }
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
