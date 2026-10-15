import SwiftUI

struct PosterGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            content()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ScrollView {
        PosterGrid {
            ForEach(0 ..< 6) { _ in
                PosterTile(posterPath: nil, rating: nil)
            }
        }
    }
    .background(AppTheme.background)
}
