import SwiftUI

struct GenrePickerSheet: View {
    let genres: [String]
    @Binding var selected: Set<String>
    var onChanged: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Genres")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if !selected.isEmpty {
                    Button {
                        selected.removeAll()
                        onChanged?()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                ForEach(genres, id: \.self) { genre in
                    let active = selected.contains(genre)
                    Button {
                        if active {
                            selected.remove(genre)
                        } else if selected.count < 3 {
                            selected.insert(genre)
                        }
                        onChanged?()
                    } label: {
                        Text(genre)
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(active ? .white : AppTheme.background)
                            .foregroundStyle(active ? .black : AppTheme.textMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        active ? .clear : AppTheme.border,
                                        lineWidth: 0.5
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
