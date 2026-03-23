import SwiftUI

struct ReelRatingOverlay: View {
    let title: String
    let tmdbId: Int
    let onDismiss: () -> Void
    let onSaved: (Double) -> Void

    @State private var rating: Double = 0
    @State private var isSaving = false
    @State private var existingRating: Double?
    @State private var appeared = false

    private var isUpdate: Bool {
        existingRating != nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Text(title)
                    .font(.system(
                        size: 16, weight: .semibold
                    ))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                StarRatingInput(
                    rating: $rating,
                    starSize: 34,
                    spacing: 12
                )

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.black)
                                .controlSize(.small)
                        } else {
                            Text(
                                isUpdate
                                    ? "Update" : "Save"
                            )
                            .font(.system(
                                size: 15,
                                weight: .semibold
                            ))
                        }
                    }
                    .frame(width: 140, height: 44)
                    .background(
                        rating > 0
                            ? .white
                            : AppTheme.border
                    )
                    .foregroundStyle(
                        rating > 0
                            ? .black
                            : AppTheme.textDim
                    )
                    .clipShape(Capsule())
                }
                .disabled(rating == 0 || isSaving)
            }
            .padding(28)
            .background(AppTheme.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        AppTheme.border, lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 44)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .task { await checkExisting() }
        .onAppear {
            withAnimation(
                .easeOut(duration: 0.2)
            ) {
                appeared = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.15
        ) {
            onDismiss()
        }
    }

    private func checkExisting() async {
        let cache = UserActionCache.shared
        if cache.isWatched(tmdbId) {
            existingRating = cache.rating(for: tmdbId)
            if let existing = existingRating {
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
            UserActionCache.shared.didRate(
                tmdbId, rating: rating
            )
            onSaved(rating)
        } catch {
            print(
                "[ReelRatingOverlay] save error: "
                    + "\(error)"
            )
        }
        isSaving = false
    }
}
