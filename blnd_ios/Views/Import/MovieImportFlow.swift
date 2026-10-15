import SwiftUI

/// Text a later notes import can send. The backend has no `/import/notes` yet.
struct NotesImportDraft: Hashable {
    enum Source: String, Hashable {
        case photos
        case paste
    }

    let source: Source
    let text: String
    let imageCount: Int
}

enum MovieImportDestination: Hashable {
    case letterboxd
    case photos
    case paste
    case notesReview(NotesImportDraft)
}

/// How the hub and the notes screens move to the next step.
/// Onboarding and Profile can use `MovieImportStackRouter`, or their own path.
@MainActor
protocol MovieImportRouting: AnyObject {
    func open(_ destination: MovieImportDestination)
}

@Observable
@MainActor
final class MovieImportStackRouter: MovieImportRouting {
    var path = NavigationPath()

    func open(_ destination: MovieImportDestination) {
        path.append(destination)
    }
}

/// The movie hub plus the screens it opens.
/// Profile and onboarding present this. A later onboarding can host the same
/// destinations on its own stack by calling `movieImportScreen`.
struct MovieImportFlow: View {
    var onComplete: () -> Void
    var onSkip: () -> Void
    @State private var router = MovieImportStackRouter()

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            BringMoviesHub(router: router, onSkip: onSkip)
                .navigationDestination(for: MovieImportDestination.self) { destination in
                    movieImportScreen(
                        destination,
                        router: router,
                        onComplete: onComplete,
                        onSkip: onSkip
                    )
                }
        }
    }
}

@ViewBuilder
func movieImportScreen(
    _ destination: MovieImportDestination,
    router: any MovieImportRouting,
    onComplete: @escaping () -> Void,
    onSkip: @escaping () -> Void
) -> some View {
    switch destination {
    case .letterboxd:
        ImportContextView(onComplete: onComplete, onSkip: onSkip)
    case .photos:
        PhotoImportView(router: router)
    case .paste:
        PasteNotesView(router: router)
    case .notesReview(let draft):
        NotesImportReviewView(draft: draft, onDone: onComplete)
    }
}
