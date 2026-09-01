import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The entire user interface: one web view on a felt background.
struct GameWebView: View {

    /// `--bg` from styles.css. Matching it here means the area outside the web
    /// view — the notch inset, the home indicator strip, and the window for the
    /// instant before the first frame paints — is the same green as the table,
    /// instead of a black letterbox.
    private static let felt = Color(red: 0x0B / 255, green: 0x1F / 255, blue: 0x16 / 255)
    private static let feltHilite = Color(red: 0x1B / 255, green: 0x49 / 255, blue: 0x3B / 255)

    /// Mirrors `radial-gradient(circle at 20% 20%, #1b493b, var(--bg) 48%)`.
    private static var feltBackground: some View {
        GeometryReader { geo in
            RadialGradient(
                gradient: Gradient(colors: [feltHilite, felt]),
                center: UnitPoint(x: 0.2, y: 0.2),
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height) * 0.48
            )
        }
    }

    /// The same colour for the AppKit/UIKit side.
    #if os(macOS)
    static let feltPlatformColor = NSColor(red: 0x0B / 255, green: 0x1F / 255, blue: 0x16 / 255, alpha: 1)
    #else
    static let feltPlatformColor = UIColor(red: 0x0B / 255, green: 0x1F / 255, blue: 0x16 / 255, alpha: 1)
    #endif

    @StateObject private var loadState = LoadState()

    var body: some View {
        ZStack {
            // The same radial gradient body{} paints in styles.css. A flat
            // fill here meant the hand-off from placeholder to page was always
            // visible, however fast it was; matching it makes the reveal a
            // non-event. WebKit needs ~400ms to boot its content process before
            // it can paint anything at all, and that is not reducible.
            Self.feltBackground.ignoresSafeArea()

            // The web view itself stays inside the safe area. The page has no
            // env(safe-area-inset-*) handling in its CSS, so edge-to-edge would
            // put the logo and title under the Dynamic Island — and adding that
            // CSS would fork Web/ away from what GitHub Pages serves, which is
            // the one thing this shell is built to avoid.
            WebViewRepresentable(loadState: loadState)
                // Felt first, then the table. WebKit takes ~400ms to boot its
                // content process, and letting it paint whenever it is ready
                // looked more jarring than holding the felt and bringing the
                // page in deliberately.
                .opacity(loadState.isLoaded ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: loadState.isLoaded)
                // Taps are gated on the same signal. WKWebView silently
                // swallows them before the page is live, which is why About and
                // Help used to need two or three presses right after launch.
                .allowsHitTesting(loadState.isLoaded)
        }
    }
}

/// Set to true when the first navigation finishes.
final class LoadState: ObservableObject {
    @Published var isLoaded = false
}

// MARK: - Platform wrappers

// AppKit and UIKit need different representable protocols, but the web view they
// wrap is identical, so the real work lives in `makeWebView` below.

#if os(macOS)
struct WebViewRepresentable: NSViewRepresentable {
    let loadState: LoadState

    func makeCoordinator() -> WebViewCoordinator { WebViewCoordinator(loadState: loadState) }

    // Each representable builds its own web view. A shared singleton instance
    // was tried to pre-warm WebKit; SwiftUI may call this more than once and
    // the same view cannot live in two hierarchies, which crashed on iOS. It
    // also saved nothing measurable (404ms vs 413ms to first paint).
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Nothing to push down — all game state lives inside the page.
    }
}
#else
struct WebViewRepresentable: UIViewRepresentable {
    let loadState: LoadState

    func makeCoordinator() -> WebViewCoordinator { WebViewCoordinator(loadState: loadState) }

    // Each representable builds its own web view. A shared singleton instance
    // was tried to pre-warm WebKit; SwiftUI may call this more than once and
    // the same view cannot live in two hierarchies, which crashed on iOS. It
    // also saved nothing measurable (404ms vs 413ms to first paint).
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to push down — all game state lives inside the page.
    }
}
#endif

private func makeWebView(coordinator: WebViewCoordinator) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.setURLSchemeHandler(coordinator.schemeHandler,
                                      forURLScheme: BundleSchemeHandler.scheme)

    // Web Audio still needs a user gesture to unlock, which the game already
    // satisfies — app.js creates the AudioContext lazily on the first click
    // rather than at load. This just removes the extra gate.
    configuration.mediaTypesRequiringUserActionForPlayback = []
    #if os(iOS)
    configuration.allowsInlineMediaPlayback = true
    #endif

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = coordinator
    webView.uiDelegate = coordinator
    webView.allowsBackForwardNavigationGestures = false
    // Public API. The private `drawsBackground` key that turns up in older
    // answers to this is an App Store rejection.
    // Matches the table felt, not black: this is what shows for the frame or
    // two before the page paints, and a dark flash over green is exactly the
    // startup flicker this used to cause.
    webView.underPageBackgroundColor = GameWebView.feltPlatformColor

    #if os(iOS)
    // The layout fits the viewport; without this, dragging anywhere on the felt
    // rubber-bands the whole table and it stops feeling like an app.
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.scrollView.showsVerticalScrollIndicator = false
    #endif

    webView.load(URLRequest(url: BundleSchemeHandler.startURL))
    return webView
}

// MARK: - Coordinator

/// Owns the scheme handler and keeps outbound links out of the game window.
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

    let schemeHandler = BundleSchemeHandler()
    private let loadState: LoadState

    init(loadState: LoadState) {
        self.loadState = loadState
        super.init()
    }

    /// The page is painted and its handlers are bound: safe to show, safe to tap.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadState.isLoaded = true
    }

    /// Ordinary in-page navigation. Everything the game loads arrives over the
    /// custom scheme; anything else is a link out and belongs in the browser.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if url.scheme == BundleSchemeHandler.scheme {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            Self.openExternally(url)
        }
    }

    /// The About panel's links carry `target="_blank"`, and those never reach
    /// `decidePolicyFor` — WKWebView asks the UI delegate for a new web view to
    /// put them in and silently drops them when there is no delegate. Which is
    /// why, without this, tapping the GitHub or Tahoe21 link does nothing at all.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            Self.openExternally(url)
        }
        return nil  // never open a second in-app window
    }

    // MARK: Failure reporting
    //
    // Without these a failed load is completely silent — the window just comes
    // up blank and there is nothing in the log to say why.

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        NSLog("[Tahoe5] provisional navigation failed: \(error)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[Tahoe5] navigation failed: \(error)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        NSLog("[Tahoe5] web content process terminated — reloading")
        webView.reload()
    }

    private static func openExternally(_ url: URL) {
        // Only ever hand the system a real web link. The app has no other
        // outbound links today, and this keeps it that way if one is ever added.
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return
        }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}
