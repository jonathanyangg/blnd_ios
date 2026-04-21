import SwiftUI

struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro
                section(
                    icon: "star.fill",
                    title: "Your taste profile",
                    body: "Every time you rate a movie, blnd learns a little more about "
                        + "what you love and what you don't. The more you rate, the sharper "
                        + "your picks get. No ratings sit in a vacuum — we look at directors, "
                        + "genres, vibes, and patterns across everything you've rated to build "
                        + "a picture of your taste."
                )
                section(
                    icon: "sparkles",
                    title: "For You",
                    body: "Your personalized feed. We compare movies we think you haven't "
                        + "seen against your taste profile and surface the ones most likely "
                        + "to click. Swipe up for the next pick, right to add to watchlist, left to save "
                        + "for later. Your taste profile refreshes automatically as you rate, "
                        + "so the feed keeps up."
                )
                section(
                    icon: "person.2.fill",
                    title: "Blends",
                    body: "Create a Blend with friends and we find movies the whole group "
                        + "would enjoy together. It's the overlap of everyone's taste — not "
                        + "an average, not a compromise. If you and your friends all rate "
                        + "more, the Blend gets smarter too."
                )
                section(
                    icon: "square.grid.2x2",
                    title: "Discover",
                    body: "Looking for something outside your usual lane? Discover skips the "
                        + "personalization and shows what's trending, top-rated, or matches "
                        + "the filters you pick. Great for casting a wider net."
                )
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("How It Works")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var intro: some View {
        Text(
            "blnd is built around one idea: the more we learn about your "
                + "taste, the better we can point you at movies you'll love."
        )
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.bottom, 4)
    }

    private var footer: some View {
        Text("Rate honestly. The system is only as good as the signal you feed it.")
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textDim)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func section(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }
}

#Preview {
    NavigationStack {
        HowItWorksView()
    }
}
