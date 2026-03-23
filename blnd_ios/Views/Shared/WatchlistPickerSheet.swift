import SwiftUI

struct WatchlistPickerSheet: View {
    let tmdbId: Int
    let isWatched: Bool
    let isInPersonalWatchlist: Bool
    let onDismiss: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var groups: [GroupResponse] = []
    @State private var isLoading = true
    @State private var isSaving = false

    // Tracks current checked state for personal + each group
    @State private var personalChecked = false
    @State private var groupChecked: [Int: Bool] = [:]

    // Tracks initial state to compute diffs on save
    @State private var initialPersonal = false
    @State private var initialGroupState: [Int: Bool] = [:]

    private var hasChanges: Bool {
        if personalChecked != initialPersonal { return true }
        for (id, checked) in groupChecked where checked != (initialGroupState[id] ?? false) {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
                Spacer()
            } else {
                listContent
            }
        }
        .task { await loadState() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            Text("Add to Watchlist")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Text("Save")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(hasChanges ? .white : AppTheme.textDim)
                }
            }
            .disabled(!hasChanges || isSaving)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - List

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Personal section
                VStack(alignment: .leading, spacing: 0) {
                    Text("PERSONAL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textDim)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)

                    checkRow(
                        icon: "person.fill",
                        label: "My Watchlist",
                        subtitle: isWatched ? "Already watched" : nil,
                        checked: personalChecked
                    ) {
                        if !isWatched {
                            personalChecked.toggle()
                        }
                    }
                    .disabled(isWatched)
                    .opacity(isWatched ? 0.5 : 1)
                }
                .padding(.bottom, 16)

                // Groups section
                if !groups.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("GROUPS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textDim)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)

                        ForEach(groups) { group in
                            checkRow(
                                icon: "person.3.fill",
                                label: group.name,
                                subtitle: "\(group.memberCount) members",
                                checked: groupChecked[group.id] ?? false
                            ) {
                                groupChecked[group.id, default: false].toggle()
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private func checkRow(
        icon: String,
        label: String,
        subtitle: String?,
        checked: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.background)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }

                Spacer()

                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(checked ? .white : AppTheme.border)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Data

    private func loadState() async {
        let cache = UserActionCache.shared

        // Use cached groups + only fetch group watchlist status from API
        groups = await cache.fetchGroups()
        personalChecked = cache.isWatchlisted(tmdbId) || isWatched
        initialPersonal = personalChecked

        // Fetch group watchlist status (lightweight — single query)
        if !groups.isEmpty {
            do {
                let sts = try await TrackingAPI
                    .getWatchlistStatus(tmdbId: tmdbId)
                let inGroups = Set(sts.groupIds)
                for group in groups {
                    let inList = inGroups.contains(group.id)
                    groupChecked[group.id] = inList
                    initialGroupState[group.id] = inList
                }
            } catch {
                // Non-fatal — groups show unchecked
            }
        }

        isLoading = false
    }

    private func save() async {
        isSaving = true

        // Personal watchlist changes
        let cache = UserActionCache.shared
        if personalChecked != initialPersonal, !isWatched {
            do {
                if personalChecked {
                    _ = try await TrackingAPI.addToWatchlist(tmdbId: tmdbId)
                    cache.didWatchlist(tmdbId)
                } else {
                    try await TrackingAPI.removeFromWatchlist(tmdbId: tmdbId)
                    cache.didRemoveFromWatchlist(tmdbId)
                }
            } catch {
                print("[WatchlistPicker] Personal watchlist error: \(error)")
            }
        }

        // Group watchlist changes
        for (groupId, checked) in groupChecked {
            let wasChecked = initialGroupState[groupId] ?? false
            guard checked != wasChecked else { continue }
            do {
                if checked {
                    _ = try await GroupsAPI.addToWatchlist(
                        groupId: groupId, tmdbId: tmdbId
                    )
                } else {
                    try await GroupsAPI.removeFromWatchlist(
                        groupId: groupId, tmdbId: tmdbId
                    )
                }
            } catch {
                print("[WatchlistPicker] Group \(groupId) error: \(error)")
            }
        }

        onDismiss(personalChecked && !isWatched)
        isSaving = false
        dismiss()
    }
}
