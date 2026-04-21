import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search movies..."
    var compact: Bool = false
    var backgroundColor: Color = AppTheme.card
    var onClear: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textDim)
                .font(.system(size: compact ? 13 : 15))

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(AppTheme.textMuted)
            )
            .font(.system(size: compact ? 13 : 15))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = false
                    onClear?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 18, height: 18)
                        .background(AppTheme.textMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(compact ? 9 : 14)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .animation(.easeOut(duration: 0.15), value: text.isEmpty)
    }
}

/// Non-interactive version for tappable search bar
struct SearchBarButton: View {
    var placeholder: String = "Search movies..."
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textDim)
                    .font(.system(size: 15))

                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)

                Spacer()
            }
            .padding(14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }
}

#Preview {
    VStack {
        SearchBar(text: .constant(""))
        SearchBar(text: .constant("inception"))
        SearchBarButton()
    }
    .padding()
    .background(AppTheme.background)
}
