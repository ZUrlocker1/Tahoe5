import SwiftUI

/// Tahoe5 — video poker.
///
/// The game itself is the unmodified web app in `Web/`, the same files GitHub
/// Pages serves at zurlocker1.github.io/Tahoe5. This target is only a native
/// shell around it: a window, an icon, and a way onto the App Store.
@main
struct Tahoe5App: App {

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            GameWebView()
                // Below roughly this width the table layout starts stacking
                // awkwardly. The stylesheet copes, but there is no reason to
                // let the window get there.
                // 600, not 520: the compact layout needs ~562px of height at this
                // width, so a shorter window clipped the payoffs and buttons.
                .frame(minWidth: 760, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            // One window, no documents. ⌘N would open a second copy of the game
            // with its own balance, which is just confusing.
            CommandGroup(replacing: .newItem) { }
        }
        #else
        WindowGroup {
            GameWebView()
        }
        #endif
    }
}
