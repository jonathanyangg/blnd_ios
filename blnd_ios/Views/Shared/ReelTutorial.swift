import SwiftUI

/// First-run reel coach. Order is the product order: interested, not for me,
/// watchlist, stars, Watch Now, then the next movie.
enum ReelTutorialStep: Int, CaseIterable, Equatable, Identifiable {
    case interested
    case notForMe
    case watchlist
    case stars
    case watchNow
    case nextMovie

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .interested: "Swipe right"
        case .notForMe: "Swipe left"
        case .watchlist: "Add to watchlist"
        case .stars: "Rate with stars"
        case .watchNow: "Watch Now"
        case .nextMovie: "Swipe up"
        }
    }

    var message: String {
        switch self {
        case .interested: "Interested. A right swipe asks for more like this."
        case .notForMe: "Not for me. It stays neutral and does not save a score."
        case .watchlist: "Tap Add to watchlist when you want to save it."
        case .stars: "Stars save a rating."
        case .watchNow: "Watch Now opens where to watch."
        case .nextMovie: "Swipe up for the next movie."
        }
    }

    /// Control to ring. Swipe steps point at the card edge instead.
    var target: ReelTutorialTarget? {
        switch self {
        case .watchlist: .watchlist
        case .stars: .stars
        case .watchNow: .watchNow
        default: nil
        }
    }

    /// Peak of the hint. Tap steps do not tilt the card.
    var nudge: ReelTutorialNudge {
        switch self {
        case .interested: ReelTutorialNudge(x: 36, y: 0, degrees: 6)
        case .notForMe: ReelTutorialNudge(x: -36, y: 0, degrees: -6)
        case .nextMovie: ReelTutorialNudge(x: 0, y: -28, degrees: 0)
        default: .rest
        }
    }

    var symbol: String {
        switch self {
        case .interested: "arrow.right"
        case .notForMe: "arrow.left"
        case .nextMovie: "arrow.up"
        default: "hand.tap.fill"
        }
    }

    static func index(for raw: Int?) -> Int {
        let count = allCases.count
        guard count > 0 else { return 0 }
        return min(max(raw ?? 0, 0), count - 1)
    }
}

enum ReelTutorialTarget: Hashable {
    case card
    case watchlist
    case stars
    case watchNow
}

struct ReelTutorialNudge: Equatable {
    var x: CGFloat
    var y: CGFloat
    var degrees: Double

    static let rest = ReelTutorialNudge(x: 0, y: 0, degrees: 0)

    func scaled(_ amount: CGFloat) -> ReelTutorialNudge {
        ReelTutorialNudge(
            x: x * amount,
            y: y * amount,
            degrees: degrees * Double(amount)
        )
    }
}

enum ReelTutorialStore {
    static let seenKey = "hasSeenReelsTutorial"

    /// True until the person finishes or skips the reel coach.
    static func shouldShow(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: seenKey)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seenKey)
    }
}

extension View {
    /// Reports this view's frame for the reel coach. The overlay must not take taps,
    /// or the card cannot be swiped once the coach is gone.
    func reelTutorialFrame(_ target: ReelTutorialTarget, active: Bool) -> some View {
        overlay {
            GeometryReader { geo in
                Color.clear.preference(
                    key: ReelTutorialFrameKey.self,
                    value: active ? [target: geo.frame(in: .named("homeReel"))] : [:]
                )
            }
            .allowsHitTesting(false)
        }
    }
}

struct ReelTutorialFrameKey: PreferenceKey {
    static var defaultValue: [ReelTutorialTarget: CGRect] = [:]

    static func reduce(
        value: inout [ReelTutorialTarget: CGRect],
        nextValue: () -> [ReelTutorialTarget: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Light coach over the live reel. The card underneath is the real one.
struct ReelTutorialOverlay: View {
    var frames: [ReelTutorialTarget: CGRect]
    @Binding var nudge: ReelTutorialNudge
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int
    @State private var phase: CGFloat = 0

    init(
        frames: [ReelTutorialTarget: CGRect],
        nudge: Binding<ReelTutorialNudge>,
        initialIndex: Int?,
        onDismiss: @escaping () -> Void
    ) {
        self.frames = frames
        _nudge = nudge
        self.onDismiss = onDismiss
        _index = State(initialValue: ReelTutorialStep.index(for: initialIndex))
    }

    private var step: ReelTutorialStep {
        ReelTutorialStep.allCases[index]
    }

    private var isLast: Bool {
        index >= ReelTutorialStep.allCases.count - 1
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                scrim(proxy)
                hint(proxy)
                chrome
            }
        }
        .accessibilityIdentifier("reel-tutorial")
        .onAppear { showStep() }
        .onChange(of: index) { _, _ in showStep() }
        .background {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                Color.clear
                    .onChange(of: context.date) { _, date in
                        guard !reduceMotion else { return }
                        phase = wave(date)
                        nudge = step.nudge.scaled(phase)
                    }
            }
        }
    }

    private func scrim(_ proxy: GeometryProxy) -> some View {
        Color.black.opacity(0.28)
            .overlay {
                if let rect = controlRect() {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .frame(width: rect.width + 14, height: rect.height + 14)
                        .position(x: rect.midX, y: rect.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func hint(_ proxy: GeometryProxy) -> some View {
        let card = cardRect(proxy)
        ZStack {
            if step.target == nil {
                edgeMark(in: card)
            }
            if let rect = controlRect() {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: rect.width + 14, height: rect.height + 14)
                    .position(x: rect.midX, y: rect.midY)
            }
            Image(systemName: step.symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(.black.opacity(0.45), in: Circle())
                .position(handPosition(in: card, proxy: proxy))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var chrome: some View {
        VStack {
            panel.padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(step.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                Text(step.message)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("reel-tutorial.title")

            HStack(spacing: 8) {
                ForEach(ReelTutorialStep.allCases) { item in
                    Circle()
                        .fill(item == step ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityIdentifier("reel-tutorial.dots")

            Button(action: advance) {
                Text(isLast ? "Got it" : "Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 200, height: 48)
                    .background(.white, in: Capsule())
            }
            .accessibilityIdentifier("reel-tutorial.next")

            Button(action: skip) {
                Text("Skip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityIdentifier("reel-tutorial.skip")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: 340)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func cardRect(_ proxy: GeometryProxy) -> CGRect {
        frames[.card] ?? CGRect(origin: .zero, size: proxy.size)
    }

    private func controlRect() -> CGRect? {
        guard let target = step.target else { return nil }
        let rect = frames[target] ?? .zero
        guard rect.width > 1, rect.height > 1 else { return nil }
        return rect
    }

    private func handPosition(in card: CGRect, proxy: GeometryProxy) -> CGPoint {
        if let rect = controlRect() {
            return CGPoint(x: rect.midX, y: rect.minY - 36)
        }
        let travel = 28 + phase * 36
        switch step {
        case .interested:
            return CGPoint(x: card.midX + travel, y: card.midY - 40)
        case .notForMe:
            return CGPoint(x: card.midX - travel, y: card.midY - 40)
        case .nextMovie:
            return CGPoint(x: card.midX, y: card.midY - travel)
        default:
            return CGPoint(x: card.midX, y: card.midY)
        }
    }

    @ViewBuilder
    private func edgeMark(in card: CGRect) -> some View {
        let bar = Capsule().fill(.white.opacity(0.55 + Double(phase) * 0.4))
        switch step {
        case .interested:
            bar.frame(width: 5, height: card.height * 0.28)
                .position(x: card.maxX - 18, y: card.midY)
        case .notForMe:
            bar.frame(width: 5, height: card.height * 0.28)
                .position(x: card.minX + 18, y: card.midY)
        case .nextMovie:
            bar.frame(width: card.width * 0.28, height: 5)
                .position(x: card.midX, y: card.minY + 28)
        default:
            EmptyView()
        }
    }

    private func showStep() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if reduceMotion {
            phase = 1
            nudge = step.nudge
        }
    }

    private func wave(_ date: Date) -> CGFloat {
        let turn = date.timeIntervalSinceReferenceDate * 2.2
        return CGFloat((sin(turn) + 1) / 2)
    }

    private func advance() {
        if isLast {
            Analytics.tutorialCompleted(tutorial: .reels)
            onDismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
        }
    }

    private func skip() {
        Analytics.tutorialSkipped(tutorial: .reels, step: index)
        onDismiss()
    }
}
