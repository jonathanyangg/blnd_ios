import SwiftUI

struct NotificationsSettingsView: View {
    @State private var friendRequests = true
    @State private var groupInvites = true
    @State private var recommendations = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                toggleRow(label: "Friend Requests", isOn: $friendRequests)
                Divider().background(AppTheme.cardSecondary)
                toggleRow(label: "Blend Invites", isOn: $groupInvites)
                Divider().background(AppTheme.cardSecondary)
                toggleRow(label: "Recommendations", isOn: $recommendations)
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Text("Notification preferences coming soon.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textDim)
                .padding(.top, 16)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .swipeBackGesture()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .tint(.green)
            .padding(16)
    }
}
