import SwiftUI

struct RateMovieSheet: View {
    let title: String
    let year: String
    let tmdbId: Int
    var posterPath: String?
    var existingRating: Double?
    var onSaved: ((Double) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 4
    @State private var isSaving = false
    @State private var saveError: String?

    private var isRerating: Bool {
        existingRating != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            StarRatingInput(rating: $rating)
                .padding(.bottom, 16)

            if let saveError {
                Text(saveError)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }

            AppButton(
                label: isRerating ? "Update Rating" : "Save",
                isLoading: isSaving
            ) {
                Task { await save() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .onAppear {
            if let existingRating {
                rating = existingRating
            }
        }
    }

    @ViewBuilder
    private var posterThumbnail: some View {
        if let url = posterPath.flatMap({ URL(string: "https://image.tmdb.org/t/p/w154\($0)") }) {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
                    .posterBlur()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.posterGradient)
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
            if isRerating {
                _ = try await TrackingAPI.updateRating(tmdbId: tmdbId, rating: rating)
            } else {
                _ = try await TrackingAPI.trackMovie(tmdbId: tmdbId, rating: rating, review: nil)
            }
            UserActionCache.shared.didRate(
                tmdbId, rating: rating
            )
            onSaved?(rating)
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
