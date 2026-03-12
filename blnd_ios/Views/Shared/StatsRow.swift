import SwiftUI

struct StatItem {
    let label: String
    let value: Int
    let onTap: (() -> Void)?
}

struct StatsRow: View {
    let items: [StatItem]

    var body: some View {
        HStack {
            ForEach(items.indices, id: \.self) { index in
                statCell(items[index])
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Divider().background(AppTheme.cardSecondary)
        }
        .overlay(alignment: .bottom) {
            Divider().background(AppTheme.cardSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func statCell(_ item: StatItem) -> some View {
        let cell = VStack(spacing: 2) {
            Text("\(item.value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(item.label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)

        if let onTap = item.onTap {
            Button(action: onTap) {
                cell
            }
            .buttonStyle(.plain)
        } else {
            cell
        }
    }
}

#Preview {
    StatsRow(items: [
        StatItem(label: "Watched", value: 42, onTap: nil),
        StatItem(label: "Watchlist", value: 10, onTap: nil),
        StatItem(label: "Friends", value: 7, onTap: {}),
        StatItem(label: "Blends", value: 3, onTap: {}),
    ])
    .background(AppTheme.background)
}
