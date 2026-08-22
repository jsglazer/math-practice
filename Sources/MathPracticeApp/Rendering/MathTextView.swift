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

/// Renders one or more LaTeX blocks, sized to whatever KaTeX actually typesets rather than
/// a guessed fixed height — the guess is what used to clip tall fractions and multi-line
/// steps. Passing several `blocks` renders them into one continuous WKWebView, which is
/// what lets a person select and copy a whole worked solution in one drag instead of one
/// step-box at a time.
struct MathTextView: View {
    let blocks: [MathBlock]
    var minHeight: CGFloat = 44

    @Environment(\.colorScheme) private var colorScheme
    @State private var measuredHeight: CGFloat?

    init(latex: String, minHeight: CGFloat = 44) {
        self.blocks = [MathBlock(latex: latex)]
        self.minHeight = minHeight
    }

    init(blocks: [MathBlock], minHeight: CGFloat = 44) {
        self.blocks = blocks
        self.minHeight = minHeight
    }

    var body: some View {
        MathWebViewBridge(
            document: MathDocument(
                blocks: blocks,
                colorScheme: colorScheme == .dark ? .dark : .light
            ),
            measuredHeight: $measuredHeight
        )
        .frame(height: max(minHeight, measuredHeight ?? minHeight))
        .accessibilityLabel(Text(blocks.map(\.latex).joined(separator: ", ")))
    }
}

/// The platform bridge. Kept as small as possible: create the renderer, hand it a document.
private struct MathWebViewBridge: PlatformViewRepresentable {
    let document: MathDocument
    let measuredHeight: Binding<CGFloat?>

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.renderer.webView
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.show(document, heightBinding: measuredHeight)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.renderer.webView
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.show(document, heightBinding: measuredHeight)
    }
    #endif

    @MainActor
    final class Coordinator {
        let renderer = MathRenderer()
        private var shown: MathDocument?
        private var task: Task<Void, Never>?

        func show(_ document: MathDocument, heightBinding: Binding<CGFloat?>) {
            guard document != shown else { return }
            shown = document
            task?.cancel()
            task = Task { [renderer] in
                // On-screen rendering has nothing to gate on completion, so a failure here
                // is cosmetic — the export path is the one that must not proceed early.
                if let height = try? await renderer.render(document) {
                    heightBinding.wrappedValue = height
                }
            }
        }
    }
}
