import SwiftUI

struct AppButton: View {
    let label: String
    var style: Style = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var isSmall: Bool = false
    var action: () -> Void = {}

    enum Style {
        case primary
        case ghost
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    Text(label)
                }
            }
            .font(.system(size: isSmall ? 13 : 16, weight: .semibold))
            .frame(maxWidth: isSmall ? nil : .infinity)
            .padding(.vertical, isSmall ? 10 : 16)
            .padding(.horizontal, isSmall ? 18 : 0)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
        .disabled(isDisabled || isLoading)
    }

    private var backgroundColor: Color {
        if isDisabled { return AppTheme.border }
        switch style {
        case .primary: return .white
        case .ghost: return AppTheme.card
        }
    }

    private var foregroundColor: Color {
        if isDisabled { return AppTheme.textDim }
        switch style {
        case .primary: return .black
        case .ghost: return .white
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AppButton(label: "Continue")
        AppButton(label: "Cancel", style: .ghost)
        AppButton(label: "Disabled", isDisabled: true)
        AppButton(label: "Small", isSmall: true)
    }
    .padding()
    .background(AppTheme.background)
}
