import SwiftUI

/// Three ways to bring movies in. Letterboxd, photos, and notes.
struct BringMoviesHub: View {
    var router: any MovieImportRouting
    var onSkip: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring your movies")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Start from Letterboxd, a photo, or notes.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.top, 12)

                    hubCard(
                        title: "Letterboxd",
                        note: "Export a file, then upload it here.",
                        identifier: "import.hub.letterboxd"
                    ) {
                        Image("letterboxd-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    } action: {
                        router.open(.letterboxd)
                    }

                    hubCard(
                        title: "Photo or screenshot",
                        note: "We'll read the titles on your phone.",
                        identifier: "import.hub.photos"
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    } action: {
                        router.open(.photos)
                    }

                    hubCard(
                        title: "Notes or text",
                        note: "Paste a list.",
                        identifier: "import.hub.notes"
                    ) {
                        Image(systemName: "note.text")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    } action: {
                        router.open(.paste)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }

            if onSkip != nil {
                AppButton(label: "Skip for now", style: .ghost) { onSkip?() }
                    .accessibilityIdentifier("import.skip")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.cardSecondary)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("import.hub.back")
            }
        }
    }

    private func hubCard<Icon: View>(
        title: String,
        note: String,
        identifier: String,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon()
                    .frame(width: 48, height: 48)
                    .background(AppTheme.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(note)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textDim)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
