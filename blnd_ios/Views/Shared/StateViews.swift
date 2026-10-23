import SwiftUI

/// Which of the four list states a screen shows. Loaded content always wins,
/// so a refresh or a failed reload never blanks a list the user can already see.
enum LoadState: Equatable {
    case loading, empty, error(UserFacingError), content

    static func resolve(isLoading: Bool, error: UserFacingError?, isEmpty: Bool) -> LoadState {
        guard isEmpty else { return .content }
        if isLoading { return .loading }
        if let error { return .error(error) }
        return .empty
    }
}

struct LoadingStateView: View {
    var body: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, AppTheme.spacingHuge + AppTheme.spacingSM)
            .accessibilityIdentifier("state.loading")
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppTheme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.textDim)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if let message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                }
                .padding(.top, AppTheme.spacingXS)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, AppTheme.spacingHuge + AppTheme.spacingLG)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("state.empty")
        .transition(.opacity)
    }
}
