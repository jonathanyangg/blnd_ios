import SwiftUI

struct RateMovieSheet: View {
    let title: String
    let year: String
    let tmdbId: Int
    var posterPath: String?
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 4
    @State private var note = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Movie info row
            HStack(spacing: 14) {
                posterThumbnail
                    .frame(width: 44, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(year)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()
            }
            .padding(.bottom, 20)

            // Star rating
            StarRatingInput(rating: $rating)
                .padding(.bottom, 16)

            // Note field
            TextField("Add a note...", text: $note, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(14)
                .background(Color(hex: 0x111111))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .lineLimit(3 ... 5)
                .padding(.bottom, 8)

            if let saveError {
                Text(saveError)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }

            AppButton(label: "Save", isLoading: isSaving) {
                Task { await save() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var posterThumbnail: some View {
        if let path = posterPath, let url = URL(string: "https://image.tmdb.org/t/p/w154\(path)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.posterGradient)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.posterGradient)
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        do {
            _ = try await TrackingAPI.trackMovie(
                tmdbId: tmdbId,
                rating: rating,
                review: note.isEmpty ? nil : note
            )
            onSaved?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    RateMovieSheet(title: "Oppenheimer", year: "2023", tmdbId: 872_585)
        .background(AppTheme.card)
}
