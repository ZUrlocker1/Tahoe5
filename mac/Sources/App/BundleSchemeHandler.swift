import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves the bundled game over a custom URL scheme instead of `file://`.
///
/// Two reasons this exists rather than a plain `loadFileURL(_:allowingReadAccessTo:)`:
///
/// 1. `index.html` references `styles.css?v=1.5.0` and `app.js?v=1.5.0`. Those
///    query strings exist to bust the GitHub Pages CDN and mean nothing locally,
///    but over `file://` WebKit resolves the literal path — query string included
///    — and the request can fail. Dropping the query here means the bundled
///    files can keep the query strings they were authored with.
///
/// 2. A custom scheme gives the page a real, stable origin. `file://` origins are
///    opaque to WKWebView, which makes `localStorage` unreliable. Nothing uses it
///    today — the balance resets on every launch — but adding persistence later
///    shouldn't mean re-plumbing how the app loads.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "tahoe5app"
    static let startURL = URL(string: "\(scheme)://game/index.html")!

    /// The `Web` folder reference copied into the app bundle.
    private let root: URL

    override init() {
        guard let resource = Bundle.main.url(forResource: "Web", withExtension: nil) else {
            // Only reachable if the folder reference in project.yml was broken,
            // in which case the app has nothing to display anyway.
            fatalError("Web/ is missing from the app bundle — check the folder reference in project.yml")
        }
        root = resource.standardizedFileURL
        super.init()
    }





    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let file = resolve(url) else {
            NSLog("[Tahoe5] scheme handler could not resolve \(urlSchemeTask.request.url?.absoluteString ?? "nil")")
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: file)
            let response = URLResponse(
                url: url,
                mimeType: Self.mimeType(forExtension: file.pathExtension),
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Every response is read synchronously out of the bundle, so by the time
        // this could be called there is nothing left in flight to cancel.
    }

    /// Maps a request URL onto a file inside `Web/`.
    ///
    /// `URL.path` already excludes the query string, which is what makes the
    /// `?v=` suffixes harmless. Returns nil for anything that resolves outside
    /// the folder, so a stray `../` can't read the rest of the bundle.
    private func resolve(_ url: URL) -> URL? {
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }

        let candidate = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        guard candidate.path.hasPrefix(root.path + "/") || candidate.path == root.path else { return nil }
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        return candidate
    }

    private static func mimeType(forExtension pathExtension: String) -> String {
        UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
