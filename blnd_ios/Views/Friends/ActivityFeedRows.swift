import SwiftUI

struct ActivityRequestRow: View {
    let request: PinnedRequest
    let isBusy: Bool
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpen) {
                ActivityAvatar(name: request.name, url: request.avatarURL)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onOpen) {
                    (Text(request.name).fontWeight(.semibold) + Text(request.kind.prompt))
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        requestButton("Accept", filled: true, action: onAccept)
                        requestButton("Decline", filled: false, action: onDecline)
                    }
                }
            }
            Spacer(minLength: 0)
            if request.isUnread { UnreadDot() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func requestButton(
        _ title: String,
        filled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(filled ? Color.white : AppTheme.cardSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(title) \(request.name)")
    }
}

struct ActivityRowView: View {
    let row: ActivityRow

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ActivityAvatar(name: row.actors.first?.name ?? "Someone", url: row.actors.first?.avatarURL)
            sentence
                .frame(maxWidth: .infinity, alignment: .leading)
            if row.isUnread { UnreadDot() }
            PosterThumb(url: row.posterURL)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var sentence: Text {
        let lead = row.lineLead.isEmpty ? Text("") : Text(row.lineLead).fontWeight(.semibold)
        let body = lead + Text(row.lineRest)
        let time = Text("  \(row.time)").foregroundStyle(AppTheme.textDim)
        return (body + time).font(.system(size: 14)).foregroundStyle(.white)
    }
}

struct ActivityAvatar: View {
    let name: String
    let url: String?

    var body: some View {
        ZStack {
            AvatarView(url: url, size: 44)
            if url == nil {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct PosterThumb: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 44, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(AppTheme.posterGradient)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }
}

struct UnreadDot: View {
    var body: some View {
        Circle()
            .fill(.blue)
            .frame(width: 8, height: 8)
            .accessibilityLabel("Unread")
    }
}

private extension PinnedRequest.Kind {
    var prompt: String {
        switch self {
        case .friend: " wants to be friends"
        case .follow: " requested to follow you"
        }
    }
}
