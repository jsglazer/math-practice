//  KaTeXAssets.swift
//  Serves the locally bundled KaTeX engine to the web view over a private URL scheme.
//
//  Every asset — the JS, the CSS and all twenty woff2 faces — ships inside the app bundle
//  and is served from it. There is no CDN, no remote font, and no network request of any
//  kind in the rendering path: the web view is never allowed to reach outside the bundle.
//
//  A private scheme is used rather than `loadFileURL` so nothing has to be copied to a
//  temporary directory first, and so the sandbox never needs a file path to hand out.

import Foundation
import WebKit

enum KaTeXAssets {
    /// The private scheme the render host page and all its subresources load over.
    static let scheme = "mathpractice-katex"

    /// The base URL relative asset references resolve against.
    static let baseURL = URL(string: "\(scheme)://engine/") ?? URL(fileURLWithPath: "/")

    /// The bundle subdirectory the assets ship in.
    static let subdirectory = "katex"

    /// The KaTeX release bundled with this app. Recorded so a font or API change is
    /// traceable to a version rather than guessed at.
    static let version = "0.16.22"
}

/// Answers asset requests out of the app bundle. Registered on the web view configuration.
final class KaTeXSchemeHandler: NSObject, WKURLSchemeHandler {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url,
              let data = load(path: url.path) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let response = URLResponse(
            url: url,
            mimeType: Self.mimeType(for: url.pathExtension),
            expectedContentLength: data.count,
            textEncodingName: url.pathExtension == "woff2" ? nil : "utf-8"
        )
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
        // Assets come straight out of the bundle, so there is nothing in flight to cancel.
    }

    /// Resolves `/katex.min.css` or `/fonts/KaTeX_Main-Regular.woff2` inside the bundle.
    private func load(path: String) -> Data? {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !relative.isEmpty, !relative.contains("..") else { return nil }

        let components = relative.split(separator: "/").map(String.init)
        guard let filename = components.last else { return nil }
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let nested = components.dropLast().joined(separator: "/")
        let directory = nested.isEmpty
            ? KaTeXAssets.subdirectory
            : "\(KaTeXAssets.subdirectory)/\(nested)"

        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: directory) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "js": return "application/javascript"
        case "css": return "text/css"
        case "woff2": return "font/woff2"
        case "html": return "text/html"
        default: return "application/octet-stream"
        }
    }
}
