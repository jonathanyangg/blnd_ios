import SwiftUI

struct GroupsListView: View {
    @State private var groups: [GroupResponse] = []
    @State private var isLoading = true
    @State private var showCreateGroup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Groups")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            showCreateGroup = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 40)
                    } else if groups.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.textDim)
                            Text("No groups yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Create a group to get blend picks")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(groups) { group in
                            NavigationLink {
                                GroupDetailView(groupId: group.id)
                            } label: {
                                GroupCardRow(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(onCreated: { await loadGroups() })
                    .presentationBackground(AppTheme.background)
            }
            .task { await loadGroups() }
            .refreshable { await loadGroups() }
            .onChange(of: showCreateGroup) {
                if !showCreateGroup {
                    Task { await loadGroups() }
                }
            }
        }
    }

    private func loadGroups() async {
        do {
            let result = try await GroupsAPI.listGroups()
            groups = result.groups
        } catch {
            print("[GroupsListView] Load failed: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Group Card Row

private struct GroupCardRow: View {
    let group: GroupResponse

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(group.memberCount) members")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            HStack(spacing: 0) {
                ForEach(
                    0 ..< min(group.memberCount, 3),
                    id: \.self
                ) { index in
                    AvatarView(size: 28, overlap: index > 0)
                }
                if group.memberCount > 3 {
                    ZStack {
                        Circle()
                            .fill(AppTheme.card)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(
                                    AppTheme.background,
                                    lineWidth: 2
                                )
                            )
                        Text("+\(group.memberCount - 3)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, -10)
                }
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

#Preview {
    GroupsListView()
}
