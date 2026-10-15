import SwiftUI

enum OnboardingV2Step: Int, CaseIterable, Identifiable {
    case valueTonight
    case valueTaste
    case loved
    case swipe
    case rate
    case match
    case blends
    case now
    case letterboxd
    case taste
    case friends

    var id: Int { rawValue }

    var isTutorial: Bool {
        switch self {
        case .swipe, .rate, .match, .blends, .now, .letterboxd, .taste:
            return true
        default:
            return false
        }
    }
}

enum OnboardingTaste {
    static let minimumLoved = 5

    static func canContinue(count: Int) -> Bool {
        count >= minimumLoved
    }
}

enum TutorialReaction: Equatable {
    case interested
    case notForMe
}

enum TutorialSwipe {
    static let threshold: CGFloat = 72

    /// Right is Interested. Left is the neutral "Not for me", not a downvote.
    static func decision(translation: CGFloat) -> TutorialReaction? {
        if translation >= threshold { return .interested }
        if translation <= -threshold { return .notForMe }
        return nil
    }
}

/// One-shot movies for the first home feed if `/recommendations/me/feed` fails.
enum OnboardingFeedSeed {
    private static var pending: [RecommendedMovieResponse]?

    static func store(_ movies: [RecommendedMovieResponse]) {
        pending = movies
    }

    static func take() -> [RecommendedMovieResponse]? {
        let movies = pending
        pending = nil
        return movies
    }
}

struct OnboardingDots: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< total, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Color.white : AppTheme.border)
                    .frame(width: index == step ? 16 : 6, height: 6)
            }
        }
        .accessibilityIdentifier("onboarding.dots")
    }
}

/// Fast onboarding: value, five loved movies, then a short interactive tutorial.
struct OnboardingV2View: View {
    @Environment(AuthState.self) private var authState
    @Environment(OnboardingState.self) private var onboardingState
    @Binding var path: NavigationPath

    @State private var step: OnboardingV2Step
    @State private var loved: Set<Int>
    @State private var showingAccount = false
    @State private var drag: CGFloat = 0
    @State private var reaction: TutorialReaction?
    @State private var rating: Double = 0
    @State private var showImport = false
    @State private var showBlend = false
    @State private var contactMatches: [SuggestedFriendResponse] = []
    @State private var sentUsernames: Set<String> = []
    @State private var isMatchingContacts = false
    @State private var didMatchContacts = false

    init(path: Binding<NavigationPath>, preview: OnboardingV2Step? = nil) {
        _path = path
        _step = State(initialValue: preview ?? .valueTonight)
        let preselect = preview == .loved || preview?.isTutorial == true
        _loved = State(initialValue: preselect ? Set(NowCatalog.movies.prefix(5).map(\.tmdbId)) : [])
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            if showingAccount {
                OnboardingAccountGate(onReady: accountReady, onSignIn: signIn)
            } else {
                stepContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showImport) {
            NavigationStack {
                LetterboxdImportHook.screen()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showImport = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showBlend) {
            CreateGroupView()
        }
        .onChange(of: step) { _, _ in
            drag = 0
            reaction = nil
        }
    }

    private var chrome: some View {
        VStack(spacing: 14) {
            HStack {
                if step != .valueTonight, !showingAccount {
                    Button {
                        back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("onboarding.back")
                }
                Spacer()
                if !showingAccount {
                    Button(step.isTutorial ? "Skip tutorial" : "Skip") {
                        skip()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .accessibilityIdentifier("onboarding.skip")
                }
            }
            OnboardingDots(step: step.rawValue, total: OnboardingV2Step.allCases.count)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .valueTonight:
            valuePage(
                title: "One movie.\nRight now.",
                subtitle: "No endless scroll. One pick for tonight, with a reason."
            )
        case .valueTaste:
            valuePage(
                title: "It starts with\nwhat you love.",
                subtitle: "Five movies is enough to tune the first recommendation."
            )
        case .loved:
            lovedPage
        case .swipe:
            swipePage
        case .rate:
            ratePage
        case .match:
            matchPage
        case .blends:
            blendsPage
        case .now:
            FindMovieNowView(onFinished: { advance() }, lovedTitles: lovedTitles)
        case .letterboxd:
            letterboxdPage
        case .taste:
            tastePage
        case .friends:
            friendsPage
        }
    }

    private func valuePage(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text(title)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.top, 12)
            Spacer()
            continueButton(label: "Continue", enabled: true)
        }
        .padding(.horizontal, 24)
    }

    private var lovedPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Movies you love")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)
            Text(lovedCountCopy)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.top, 6)
                .padding(.bottom, 16)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(NowCatalog.movies) { movie in
                        posterButton(movie)
                    }
                }
            }
            continueButton(
                label: OnboardingTaste.canContinue(count: loved.count) ? "Continue" : "Pick \(OnboardingTaste.minimumLoved - loved.count) more",
                enabled: OnboardingTaste.canContinue(count: loved.count)
            )
            .padding(.top, 12)
        }
        .padding(.horizontal, 24)
    }

    private func posterButton(_ movie: RecommendedMovieResponse) -> some View {
        let selected = loved.contains(movie.tmdbId)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            if selected {
                loved.remove(movie.tmdbId)
            } else {
                loved.insert(movie.tmdbId)
            }
        } label: {
            PosterTile(posterPath: movie.posterPath, rating: nil)
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white, lineWidth: 2)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }
        }
        .accessibilityIdentifier("onboarding.poster.\(movie.tmdbId)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var lovedCountCopy: String {
        if OnboardingTaste.canContinue(count: loved.count) {
            return "\(loved.count) selected. These seed your recommendations."
        }
        return "Pick \(OnboardingTaste.minimumLoved) or more. We'll use them right away."
    }

    private var practiceMovie: RecommendedMovieResponse {
        NowCatalog.movies.first { !loved.contains($0.tmdbId) } ?? NowCatalog.movies[0]
    }

    private var swipePage: some View {
        VStack(spacing: 0) {
            tutorialTitle("Swipe it", subtitle: "Right means Interested. Left is Not for me — neutral, not a downvote.")
            MovieCard(
                tmdbId: practiceMovie.tmdbId,
                title: practiceMovie.title,
                year: practiceMovie.yearString,
                posterPath: practiceMovie.posterPath,
                width: 160,
                height: 240
            )
            .offset(x: drag)
            .rotationEffect(.degrees(Double(drag) / 18))
            .gesture(
                DragGesture()
                    .onChanged { drag = $0.translation.width }
                    .onEnded { value in
                        if let decision = TutorialSwipe.decision(translation: value.translation.width) {
                            choose(decision)
                        }
                        withAnimation(.spring(duration: 0.3)) { drag = 0 }
                    }
            )
            .padding(.top, 8)
            reactionButtons
            Spacer(minLength: 8)
            continueButton(label: "Next", enabled: reaction != nil)
        }
        .padding(.horizontal, 24)
        .accessibilityIdentifier("tutorial.swipe")
    }

    private var ratePage: some View {
        VStack(spacing: 0) {
            tutorialTitle("Rate it", subtitle: "Stars save a real rating. Not for me skips without a score.")
            StarRatingInput(rating: $rating, starSize: 36)
                .padding(.top, 28)
                .accessibilityIdentifier("tutorial.rate")
            reactionButtons
            Spacer()
            continueButton(label: "Next", enabled: rating > 0 || reaction == .notForMe)
        }
        .padding(.horizontal, 24)
    }

    private var reactionButtons: some View {
        HStack(spacing: 12) {
            reactionButton("Not for me", reaction: .notForMe, id: "tutorial.notForMe")
            reactionButton("Interested", reaction: .interested, id: "tutorial.interested")
        }
        .padding(.top, 20)
    }

    private func reactionButton(_ title: String, reaction choice: TutorialReaction, id: String) -> some View {
        let selected = reaction == choice
        return Button {
            choose(choice)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(selected ? .black : .white)
                .background(selected ? Color.white : AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
        .accessibilityIdentifier(id)
    }

    private var matchPage: some View {
        VStack(spacing: 16) {
            tutorialTitle("Match %", subtitle: "How close this movie is to the taste you just gave us.")
            TasteMatchBadge(percentage: practiceMovie.scorePercent, size: 96)
                .accessibilityIdentifier("tutorial.match")
            Text("\(practiceMovie.title) is a \(practiceMovie.scorePercent)% match")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            continueButton(label: "Next", enabled: true)
        }
        .padding(.horizontal, 24)
    }

    private var blendsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            tutorialTitle("Watch it with someone", subtitle: "Invite a friend, or start a Blend — a shared list.")
            ShareLink(item: inviteURL) {
                actionLabel("Invite a friend", systemImage: "person.badge.plus")
            }
            .accessibilityIdentifier("tutorial.invite")
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showBlend = true
            } label: {
                actionLabel("Start a Blend", systemImage: "circle.grid.2x2")
            }
            .accessibilityIdentifier("tutorial.blend")
            Spacer()
            continueButton(label: "Next", enabled: true)
        }
        .padding(.horizontal, 24)
    }

    private var letterboxdPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            tutorialTitle("Bring Letterboxd", subtitle: "Optional. Import the ratings you already have, or skip it.")
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showImport = true
            } label: {
                actionLabel("Import from Letterboxd", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("tutorial.letterboxd")
            Spacer()
            continueButton(label: "Not now", enabled: true)
        }
        .padding(.horizontal, 24)
    }

    private var tastePage: some View {
        VStack(alignment: .leading, spacing: 12) {
            tutorialTitle("Your taste profile", subtitle: "Built from the movies you loved. It sharpens with every rating.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lovedMovies) { movie in
                        PosterTile(posterPath: movie.posterPath, rating: 5)
                            .frame(width: 72)
                    }
                }
            }
            .accessibilityIdentifier("tutorial.taste")
            Text(tasteGenres)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
            Spacer()
            continueButton(label: "Next", enabled: true)
        }
        .padding(.horizontal, 24)
    }

    private var friendsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            tutorialTitle(
                "Find friends",
                subtitle: "Next we'll ask to read your contacts. Phone numbers are sent to blnd only to find people already here. We keep a number only when it matches an account, and we never store names. Skip if you'd rather just send an invite."
            )
            Button {
                Task { await matchContacts() }
            } label: {
                actionLabel(
                    isMatchingContacts ? "Matching…" : "Match contacts",
                    systemImage: "person.crop.circle.badge.checkmark"
                )
            }
            .disabled(isMatchingContacts)
            .accessibilityIdentifier("onboarding.matchContacts")
            ShareLink(item: inviteURL) {
                actionLabel("Invite via share sheet", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("onboarding.invite")
            if didMatchContacts, contactMatches.isEmpty {
                Text("No contacts on blnd yet. An invite still works.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
            }
            if !contactMatches.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(contactMatches) { friend in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName ?? friend.username)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("@\(friend.username)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.textMuted)
                                }
                                Spacer()
                                Button(sentUsernames.contains(friend.username) ? "Sent" : "Add") {
                                    Task { await sendFriendRequest(friend) }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.white)
                                .clipShape(Capsule())
                                .disabled(sentUsernames.contains(friend.username))
                            }
                        }
                    }
                }
            }
            Spacer()
            continueButton(label: "See your feed", enabled: true)
        }
        .padding(.horizontal, 24)
        .accessibilityIdentifier("onboarding.findFriends")
    }

    private var inviteURL: URL {
        URL(string: "https://blnd.movie")!
    }

    private func tutorialTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 16)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private func continueButton(label: String, enabled: Bool) -> some View {
        AppButton(label: label, isDisabled: !enabled) {
            advance()
        }
        .padding(.bottom, 24)
        .accessibilityIdentifier("onboarding.continue")
    }

    private var lovedMovies: [RecommendedMovieResponse] {
        NowCatalog.movies.filter { loved.contains($0.tmdbId) }
    }

    private var lovedTitles: [String] {
        lovedMovies.map(\.title)
    }

    private var tasteGenres: String {
        let names = Array(Set(lovedMovies.compactMap(\.genres.first?.name))).sorted()
        if names.isEmpty { return "Rate a few more and this fills in." }
        return names.joined(separator: " · ")
    }

    private func choose(_ choice: TutorialReaction) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        reaction = choice
        if step == .rate, choice == .interested, rating == 0 {
            rating = 4
        }
        if !UITestLaunch.usesMockNow {
            let tmdbId = practiceMovie.tmdbId
            Task {
                if step == .swipe, choice == .interested {
                    _ = try? await TrackingAPI.addToWatchlist(tmdbId: tmdbId)
                }
                if step == .rate, choice == .interested {
                    let score = rating == 0 ? 4.0 : rating
                    _ = try? await TrackingAPI.trackMovie(tmdbId: tmdbId, rating: score)
                }
            }
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step == .loved {
            commitLoved()
            if needsAccount {
                showingAccount = true
                return
            }
            startSeed()
        }
        guard let next = OnboardingV2Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func back() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let previous = OnboardingV2Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.25)) { step = previous }
    }

    private func skip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step.isTutorial {
            withAnimation(.easeInOut(duration: 0.25)) { step = .friends }
            return
        }
        if step == .loved {
            commitLoved()
            if needsAccount {
                showingAccount = true
                return
            }
            startSeed()
        }
        guard let next = OnboardingV2Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    /// Asks for contacts access, uploads numbers, then lists people already on blnd.
    private func matchContacts() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isMatchingContacts = true
        defer { isMatchingContacts = false }
        let numbers = await ContactsHelper.fetchPhoneNumbers()
        guard !numbers.isEmpty, !UITestLaunch.usesMockNow else { return }
        do {
            try await FriendsAPI.uploadContacts(phoneNumbers: numbers)
            let response = try await FriendsAPI.getSuggestions()
            contactMatches = response.contacts
            didMatchContacts = true
        } catch {
            // Keep the invite button. A failed upload is not "nobody you know is here."
        }
    }

    private func sendFriendRequest(_ friend: SuggestedFriendResponse) async {
        guard !UITestLaunch.usesMockNow else {
            sentUsernames.insert(friend.username)
            return
        }
        do {
            _ = try await FriendsService.sendRequest(username: friend.username)
            sentUsernames.insert(friend.username)
        } catch {
            // The row stays so they can retry. A failed request is not a match.
        }
    }

    private var needsAccount: Bool {
        if UITestLaunch.usesMockNow { return false }
        return KeychainManager.readString(key: "accessToken") == nil
    }

    private func commitLoved() {
        onboardingState.movieRatings = Dictionary(uniqueKeysWithValues: loved.map { ($0, 5.0) })
        onboardingState.ratedMovies = lovedMovies.map {
            RatedMovie(tmdbId: $0.tmdbId, title: $0.title, year: $0.year, posterPath: $0.posterPath, rating: 5)
        }
    }

    private func startSeed() {
        let ratings = onboardingState.movieRatings
        guard !UITestLaunch.usesMockNow, !ratings.isEmpty else { return }
        Task {
            for (tmdbId, rating) in ratings {
                _ = try? await TrackingAPI.trackMovie(tmdbId: tmdbId, rating: rating)
            }
            _ = try? await RecommendationsAPI.refresh()
        }
    }

    private func accountReady() {
        showingAccount = false
        startSeed()
        withAnimation { step = .swipe }
    }

    private func signIn() {
        path.removeLast(path.count)
        path.append(AuthRoute.login)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenReelsTutorial")
        OnboardingFeedSeed.store(NowCatalog.feed)
        onboardingState.reset()
        Analytics.onboardingCompleted()
        Task {
            await authState.fetchCurrentUser()
            if authState.phase != .unauthenticated {
                authState.phase = .authenticated
            }
        }
    }
}

private struct OnboardingAccountGate: View {
    var onReady: () -> Void
    var onSignIn: () -> Void
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SignUpView(path: $path, onAccountReady: onReady, onSignIn: onSignIn)
                .navigationDestination(for: AuthRoute.self) { route in
                    if route == .chooseUsername {
                        ChooseUsernameView(path: $path, onAccountReady: onReady)
                    }
                }
        }
    }
}
