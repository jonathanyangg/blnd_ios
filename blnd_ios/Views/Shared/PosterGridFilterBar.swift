import SwiftUI

/// Search + sort header shown above watched / watchlist poster grids.
/// `allowsRating` hides rating sort options on watchlist (no ratings to sort by).
struct PosterGridFilterBar: View {
    @Binding var query: String
    @Binding var sort: MovieSortOption
    var allowsRating: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            SearchBar(text: $query, placeholder: "Search titles...")
                .frame(maxWidth: .infinity)

            Menu {
                ForEach(visibleOptions) { option in
                    Button {
                        sort = option
                    } label: {
                        if sort == option {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
    }

    /// Title sorts intentionally omitted — rarely useful for a personal library.
    private var visibleOptions: [MovieSortOption] {
        MovieSortOption.allCases.filter { option in
            if option == .titleAsc || option == .titleDesc { return false }
            if !allowsRating, !option.appliesToWatchlist { return false }
            return true
        }
    }
}
