import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(AuthState.self) var authState
    @Environment(OnboardingState.self) var onboardingState
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            if isSubmitting {
                OnboardingLoaderView()
            } else {
                readyContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
    }

    private var readyContent: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(step: 4, total: 4)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 0) {
                Text("You're all set")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Here's what we think you'll love")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, 32)

                // Fanned movie posters from liked movies
                let liked = Array(onboardingState.likedMovies.prefix(3))
                HStack(spacing: -8) {
                    ForEach(
                        Array(liked.enumerated()),
                        id: \.element.tmdbId
                    ) { index, movie in
                        let isCenter = liked.count > 1
                            && index == liked.count / 2
                        MovieCard(
                            title: movie.title,
                            year: movie.year.map { String($0) } ?? "",
                            posterPath: movie.posterPath,
                            width: isCenter ? 100 : 90,
                            height: isCenter ? 148 : 130,
                            glow: isCenter
                        )
                        .offset(y: isCenter ? 0 : 8)
                        .zIndex(isCenter ? 1 : 0)
                    }
                }
            }

            Spacer()

            AppButton(label: "Let's go") {
                Task { await submitAndFinish() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }

    private func submitAndFinish() async {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSubmitting = true
        }

        if onboardingState.isAppleSignUp {
            // Apple flow: genres + ratings already sent via /auth/complete-onboarding
            // Just show the loader animation, then finish
        } else {
            // Email flow: submit genres + ratings individually
            let genres = Array(onboardingState.selectedGenres)
            if !genres.isEmpty {
                _ = try? await AuthAPI.updateProfile(
                    favoriteGenres: genres
                )
            }

            for (tmdbId, liked) in onboardingState.movieRatings {
                let rating: Double = liked ? 4.0 : 2.0
                _ = try? await TrackingAPI.trackMovie(
                    tmdbId: tmdbId,
                    rating: rating
                )
            }
        }

        // Ensure loader shows for at least 3 seconds total
        try? await Task.sleep(for: .seconds(1))

        onboardingState.reset()
        authState.phase = .authenticated
    }
}

// MARK: - Progressive Onboarding Loader

private struct OnboardingLoaderView: View {
    @State private var currentStep = 0
    @State private var progress: CGFloat = 0
    @State private var textOpacity: Double = 1

    private let steps: [(icon: String, message: String)] = [
        ("brain.head.profile", "Understanding your taste profile"),
        ("film.stack", "Analyzing your movie preferences"),
        ("sparkles", "Finding your perfect recommendations"),
        ("person.2", "Preparing your experience"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .id(currentStep)

                VStack(spacing: 8) {
                    Text(steps[currentStep].message)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                        .animation(
                            .easeInOut(duration: 0.3),
                            value: textOpacity
                        )

                    Text("This only takes a moment")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textDim)
                }
            }

            Spacer()

            // Progress bar
            VStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.border)
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
                            .frame(
                                width: geo.size.width * progress,
                                height: 3
                            )
                            .animation(
                                .easeInOut(duration: 0.6),
                                value: progress
                            )
                    }
                }
                .frame(height: 3)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textDim)
                    .monospacedDigit()
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 80)
        }
        .task {
            await animateSteps()
        }
    }

    private func animateSteps() async {
        let stepCount = steps.count
        let interval: UInt64 = 800_000_000 // 0.8s per step

        for idx in 0 ..< stepCount {
            // Fade out old text
            withAnimation { textOpacity = 0 }
            try? await Task.sleep(nanoseconds: 150_000_000)

            // Switch step + update progress
            withAnimation {
                currentStep = idx
                progress = CGFloat(idx + 1) / CGFloat(stepCount)
                textOpacity = 1
            }

            try? await Task.sleep(nanoseconds: interval)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingCompleteView()
            .environment(AuthState())
            .environment(OnboardingState())
    }
}
