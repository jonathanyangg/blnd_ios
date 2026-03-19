import SwiftUI

struct ReelRatingOverlay: View {
    let title: String
    let tmdbId: Int
    let onDismiss: () -> Void
    let onSaved: (Double) -> Void

    @State private var rating: Double = 0
    @State private var isSaving = false
    @State private var existingRating: Double?

    private var isUpdate: Bool {
        existingRating != nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                StarRatingInput(rating: $rating, starSize: 32, spacing: 12)

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.black)
                                .controlSize(.small)
                        } else {
                            Text(isUpdate ? "Update" : "Save")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .frame(width: 120, height: 40)
                    .background(rating > 0 ? .white : AppTheme.border)
                    .foregroundStyle(rating > 0 ? .black : AppTheme.textDim)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(rating == 0 || isSaving)
            }
            .padding(24)
            .background(AppTheme.card.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
        .task { await checkExisting() }
    }

    private func checkExisting() async {
        if let watched = await TrackingAPI.getWatchedMovie(tmdbId: tmdbId) {
            existingRating = watched.rating
            if let existing = watched.rating {
                rating = existing
            }
        }
    }

    private func save() async {
        isSaving = true
        do {
            if isUpdate {
                _ = try await TrackingAPI.updateRating(
                    tmdbId: tmdbId, rating: rating
                )
            } else {
                _ = try await TrackingAPI.trackMovie(
                    tmdbId: tmdbId, rating: rating
                )
            }
            onSaved(rating)
        } catch {
            print("[ReelRatingOverlay] save error: \(error)")
        }
        isSaving = false
    }
}
