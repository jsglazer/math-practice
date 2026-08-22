//  MathTextView.swift
//  The SwiftUI view that shows one typeset expression on screen.
//
//  A thin wrapper over `MathRenderer`. It deliberately shares no state with the export
//  path beyond the renderer type itself — the export builds its own renderer, so a screen
//  refresh can never disturb a PDF in flight.

import MathPracticeCore
import SwiftUI
import WebKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// Renders one LaTeX string, sized to the surrounding layout.
struct MathTextView: View {
    let latex: String
    var height: CGFloat = 62

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MathWebViewBridge(
            document: MathDocument.expression(
                latex,
                colorScheme: colorScheme == .dark ? .dark : .light
            )
        )
        .frame(height: height)
        .accessibilityLabel(Text(latex))
    }
}

/// The platform bridge. Kept as small as possible: create the renderer, hand it a document.
private struct MathWebViewBridge: PlatformViewRepresentable {
    let document: MathDocument

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.renderer.webView
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.show(document)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.renderer.webView
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.show(document)
    }
    #endif

    @MainActor
    final class Coordinator {
        let renderer = MathRenderer()
        private var shown: MathDocument?
        private var task: Task<Void, Never>?

        func show(_ document: MathDocument) {
            guard document != shown else { return }
            shown = document
            task?.cancel()
            task = Task { [renderer] in
                // On-screen rendering has nothing to gate on completion, so a failure here
                // is cosmetic — the export path is the one that must not proceed early.
                try? await renderer.render(document)
            }
        }
    }
}
