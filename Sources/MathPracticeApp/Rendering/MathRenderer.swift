//  MathRenderer.swift
//  The one shell type that owns KaTeX rendering, and the ONE place render completion is
//  awaited anywhere in this codebase.
//
//  WKWebView's PDF generation is asynchronous and will happily emit a blank page — or raw
//  LaTeX — if it is invoked before KaTeX has finished putting glyphs in the DOM. The fix is
//  not a timeout and not a polling loop, either of which would be a race dressed up as a
//  fix. Instead the page posts a completion message to a `WKScriptMessageHandler` once
//  `katex.render` has run over every block AND `document.fonts.ready` has resolved, and
//  that message resolves the single continuation below.
//
//  NOTE FOR REVIEW: `awaitRenderCompletion()` is the only `withCheckedThrowingContinuation`
//  for rendering in the app, and `pdfData()` cannot be reached without passing through it —
//  it re-checks `state == .rendered` and throws otherwise, so ordering is enforced by a
//  guard rather than by convention.

import Foundation
import WebKit

enum MathRenderError: Error, LocalizedError {
    /// KaTeX reported a failure, or the page could not be loaded.
    case renderFailed(String)
    /// PDF generation was reached without a completed render. Should be unreachable.
    case notRendered
    /// The renderer was torn down while a render was in flight.
    case cancelled

    var errorDescription: String? {
        switch self {
        case let .renderFailed(message): return "Maths rendering failed: \(message)"
        case .notRendered: return "The page had not finished rendering."
        case .cancelled: return "Rendering was cancelled."
        }
    }
}

@MainActor
final class MathRenderer: NSObject {
    /// The JS-side name of the completion channel. Referenced by `MathDocument.html()`.
    nonisolated static let messageHandlerName = "mathPracticeRenderComplete"

    private enum State: Equatable {
        case idle
        case rendering
        case rendered
        case failed(String)
    }

    let webView: WKWebView

    private var state: State = .idle
    private var continuation: CheckedContinuation<Void, any Error>?

    init(bundle: Bundle = .main) {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(KaTeXSchemeHandler(bundle: bundle), forURLScheme: KaTeXAssets.scheme)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        configuration.userContentController.add(self, name: Self.messageHandlerName)
        webView.navigationDelegate = self
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #else
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        #endif
    }

    deinit {
        // The continuation must be resolved exactly once, even on teardown.
        continuation?.resume(throwing: MathRenderError.cancelled)
    }

    /// Loads `document` and returns only once KaTeX says every block is typeset.
    ///
    /// THIS IS THE SINGLE RENDER-COMPLETION AWAIT POINT IN THE CODEBASE.
    func render(_ document: MathDocument) async throws {
        finishPending(with: MathRenderError.cancelled)
        state = .rendering
        webView.loadHTMLString(document.html(), baseURL: KaTeXAssets.baseURL)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            self.continuation = continuation
        }
    }

    /// Renders `document` and returns its PDF.
    ///
    /// The render is awaited first, and the completed state is then re-checked, so
    /// `createPDF` can never be reached on a page KaTeX has not finished with.
    func pdfData(
        for document: MathDocument,
        configuration: WKPDFConfiguration = WKPDFConfiguration()
    ) async throws -> Data {
        try await render(document)
        guard state == .rendered else { throw MathRenderError.notRendered }
        return try await webView.pdf(configuration: configuration)
    }

    private func finishPending(with error: (any Error)?) {
        guard let pending = continuation else { return }
        continuation = nil
        if let error {
            pending.resume(throwing: error)
        } else {
            pending.resume()
        }
    }
}

// MARK: - Render completion channel

extension MathRenderer: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = message.body as? [String: Any]
        let status = body?["status"] as? String ?? "failed"
        let detail = body?["message"] as? String ?? "unknown rendering error"
        let failures = (body?["failures"] as? [Any])?.count ?? 0

        guard status == "rendered" else {
            state = .failed(detail)
            finishPending(with: MathRenderError.renderFailed(detail))
            return
        }
        guard failures == 0 else {
            let summary = "\(failures) expression(s) could not be typeset"
            state = .failed(summary)
            finishPending(with: MathRenderError.renderFailed(summary))
            return
        }
        state = .rendered
        finishPending(with: nil)
    }
}

extension MathRenderer: WKNavigationDelegate {
    // A page that fails to load will never post the completion message, so the failure has
    // to be turned into one here or the await would hang forever. `WKNavigation!` is the
    // delegate's own signature and cannot be narrowed.
    // swiftlint:disable implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        state = .failed(error.localizedDescription)
        finishPending(with: MathRenderError.renderFailed(error.localizedDescription))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        state = .failed(error.localizedDescription)
        finishPending(with: MathRenderError.renderFailed(error.localizedDescription))
    }
    // swiftlint:enable implicitly_unwrapped_optional
}
