import SwiftUI

// MARK: - View Sections

extension ImportContextView {
    var instructionsContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring your Letterboxd movies")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Export them from Letterboxd first, then upload the file here.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.top, 8)
                    .accessibilityIdentifier("import.guide")

                    exportStep
                    uploadStep
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }

            skipForNowButton
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden(false)
    }

    var exportStep: some View {
        stepCard(
            number: 1,
            symbol: "arrow.up.doc",
            title: "Export from Letterboxd",
            note: "Sign in, tap Export Your Data, and look for the .zip in Files."
        ) {
            AppButton(label: "Open Letterboxd") { openLetterboxdExportPage() }
                .accessibilityIdentifier("import.export")
        }
    }

    var uploadStep: some View {
        stepCard(
            number: 2,
            symbol: "tray.and.arrow.down",
            title: "Upload to blnd",
            note: "Choose the .zip, or watched.csv or ratings.csv."
        ) {
            AppButton(label: "Choose a file") { showFileImporter = true }
                .accessibilityIdentifier("import.upload")
        }
    }

    var loadingContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)
            Text("Importing your movies")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text("This can take a minute.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .accessibilityIdentifier("import.progress")
        .transition(.opacity)
    }

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

    func fileErrorContent(message: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text("We couldn't use that file")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("import.wrongFile")
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            AppButton(label: "Choose another file") { chooseAnotherFile() }
                .accessibilityIdentifier("import.chooseAgain")
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            skipForNowButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .transition(.opacity)
    }

    func errorContent(message: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("Import failed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            HStack(spacing: 12) {
                AppButton(label: "Back", style: .ghost) {
                    withAnimation {
                        viewState = .instructions
                        zipData = nil
                    }
                }
                AppButton(label: "Try Again") { startUpload() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .transition(.opacity)
    }
}

extension ImportContextView {
    func stepCard<Action: View>(
        number: Int,
        symbol: String,
        title: String,
        note: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            stepIllustration(symbol, number: number)
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(note)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                action()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    func stepIllustration(_ symbol: String, number: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AppTheme.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(.white)
                .clipShape(Circle())
                .offset(x: -6, y: -6)
        }
        .padding(.top, 6)
        .padding(.leading, 6)
        .accessibilityHidden(true)
    }

    var skipForNowButton: some View {
        AppButton(label: "Skip for now", style: .ghost) { skipForNow() }
            .accessibilityIdentifier("import.skip")
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
    }

    func resultHeader(summary: ImportSummaryResponse) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .padding(.top, 48)
                .accessibilityHidden(true)

            Text("All set")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 28) {
                importStat(
                    count: summary.imported,
                    singular: "movie",
                    plural: "movies",
                    symbol: "film",
                    identifier: "import.movies"
                )
                importStat(
                    count: importedRatings,
                    singular: "rating",
                    plural: "ratings",
                    symbol: "star",
                    identifier: "import.ratings"
                )
            }
        }
    }

    func importStat(
        count: Int,
        singular: String,
        plural: String,
        symbol: String,
        identifier: String
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
            Text("\(count)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text(count == 1 ? singular : plural)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textMuted)
        }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(count) \(count == 1 ? singular : plural)")
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
