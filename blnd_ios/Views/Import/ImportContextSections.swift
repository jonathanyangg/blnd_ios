import SwiftUI

// MARK: - View Sections

extension ImportContextView {
    // MARK: - Question

    var questionContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Do you use Letterboxd?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("We can import your watched movies and ratings.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
            .padding(.horizontal, 24)

            Spacer()

            AppButton(label: "Yes") { answerUsesLetterboxd(true) }
                .accessibilityIdentifier("import.question.yes")
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            AppButton(label: "No", style: .ghost) { answerUsesLetterboxd(false) }
                .accessibilityIdentifier("import.question.no")
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(AppTheme.background)
        .transition(.opacity)
    }

    // MARK: - Instructions

    var instructionsContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import from Letterboxd")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Bring your watched movies and ratings into blnd.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    VStack(spacing: 0) {
                        stepRow(
                            number: 1,
                            title: "Sign in",
                            desc: "Log in to your Letterboxd account in the browser"
                        )
                        stepDivider()
                        stepRow(
                            number: 2,
                            title: "Export data",
                            desc: "Tap the \"Export Your Data\" button on the settings page"
                        )
                        stepDivider()
                        stepRow(
                            number: 3,
                            title: "Done",
                            desc: "We'll import your ratings automatically"
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    privacyNote
                }
            }

            AppButton(label: "Continue") {
                showWebView = true
            }
            .accessibilityIdentifier("import.continue")
            .padding(.horizontal, 24)
            .padding(.bottom, onSkip == nil ? 16 : 8)

            if let onSkip {
                AppButton(label: "Skip", style: .ghost) {
                    onSkip()
                }
                .accessibilityIdentifier("import.skip")
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden(false)
    }

    // MARK: - Loading

    var loadingContent: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)
            Text("Importing your movies...")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .transition(.opacity)
    }

    // MARK: - Results

    func resultsContent(summary: ImportSummaryResponse) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    resultHeader(summary: summary)
                    resultStats(summary: summary)
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .accessibilityIdentifier("import.results")

            AppButton(label: "Done") { finish() }
                .accessibilityIdentifier("import.done")
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(AppTheme.background)
        .transition(.opacity)
    }

    // MARK: - Error

    func errorContent(message: UserFacingError) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ErrorStateView(message: message) {
                startUpload()
            }
            Spacer()
            AppButton(label: "Back", style: .ghost) {
                withAnimation {
                    viewState = .instructions
                    capturedZipData = nil
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .transition(.opacity)
    }
}

// MARK: - Helpers

extension ImportContextView {
    func stepRow(number: Int, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(.white)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.vertical, 14)
    }

    func stepDivider() -> some View {
        Divider()
            .overlay(AppTheme.border)
            .padding(.leading, 38)
    }

    var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
                .padding(.top, 1)

            Text(
                "Your Letterboxd credentials are never stored. "
                    + "The browser session is discarded after import."
            )
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textDim)
            .lineSpacing(2)
        }
        .padding(.horizontal, 24)
    }

    func resultHeader(summary: ImportSummaryResponse) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .padding(.top, 60)

            Text("Import Complete")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 4) {
                Text("\(summary.imported)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
                Text("movies imported")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    @ViewBuilder
    func resultStats(summary: ImportSummaryResponse) -> some View {
        if summary.skipped > 0 || summary.failed > 0 {
            VStack(spacing: 6) {
                if summary.skipped > 0 {
                    statRow(count: summary.skipped, label: "already in library")
                }
                if summary.failed > 0 {
                    statRow(count: summary.failed, label: "couldn't match")
                }
            }
        }

        if summary.failed > 0, !summary.failedTitles.isEmpty {
            failedTitlesList(summary.failedTitles)
        }
    }

    func statRow(count: Int, label: String) -> some View {
        Text("\(count) \(label)")
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textMuted)
    }

    func failedTitlesList(_ titles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxHeight: 180)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }
}
