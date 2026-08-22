//  MathDocument.swift
//  The HTML the renderer typesets.
//
//  Built here as plain strings so the page is fully described in one readable place, and
//  so the worksheet layout is the same code path as the on-screen one.

import Foundation
import MathPracticeCore

/// One typeset block on the page.
struct MathBlock: Hashable {
    enum Style: String {
        case display
        case inline
    }

    let latex: String
    let style: Style
    /// Optional label printed before the maths, e.g. a worksheet question number.
    let label: String?

    init(latex: String, style: Style = .display, label: String? = nil) {
        self.latex = latex
        self.style = style
        self.label = label
    }
}

/// A page of maths to typeset.
struct MathDocument: Hashable {
    let title: String?
    let subtitle: String?
    let blocks: [MathBlock]
    /// Space left under each block for working, in points. Zero for on-screen rendering.
    let workingSpace: Int
    let colorScheme: ColorScheme

    enum ColorScheme: String, Hashable {
        case light
        case dark
    }

    init(
        title: String? = nil,
        subtitle: String? = nil,
        blocks: [MathBlock],
        workingSpace: Int = 0,
        colorScheme: ColorScheme = .light
    ) {
        self.title = title
        self.subtitle = subtitle
        self.blocks = blocks
        self.workingSpace = workingSpace
        self.colorScheme = colorScheme
    }

    /// A single expression, the on-screen case.
    static func expression(_ latex: String, colorScheme: ColorScheme = .light) -> MathDocument {
        MathDocument(blocks: [MathBlock(latex: latex)], colorScheme: colorScheme)
    }

    /// A printable worksheet: numbered questions with room to work underneath.
    static func worksheet(_ worksheet: Worksheet) -> MathDocument {
        MathDocument(
            title: worksheet.name,
            subtitle: Self.dateFormatter.string(from: worksheet.createdAt),
            blocks: worksheet.questions.map { question in
                MathBlock(latex: question.problem.promptLatex, label: "\(question.number).")
            },
            workingSpace: 120
        )
    }

    /// A session review page: every entry with its ID/level/outcome, plus the problem's
    /// prompt (and, per `detail`, its answer/steps) wherever `resolve` can reconstruct it.
    /// Entries logged before problem instances carried a `seed` cannot be reconstructed —
    /// those print with a note instead of hanging the export on missing content.
    static func session(
        _ session: PracticeSession,
        registry: TopicRegistry,
        detail: SessionExportDetail,
        resolve: (SessionEntry) -> GeneratedProblem?
    ) -> MathDocument {
        // Oldest first, matching the order they were actually worked in.
        let ordered = session.entries.reversed()
        var blocks: [MathBlock] = []
        for (index, entry) in ordered.enumerated() {
            let number = index + 1
            let topicText = entry.key.map(registry.displayName) ?? "—"
            let levelText = entry.difficulty.map { "Level \($0)" } ?? ""
            let idText = entry.problemID.map { "ID \($0)" } ?? ""
            let outcomeText: String
            switch entry.outcome {
            case .correct: outcomeText = "Right"
            case .incorrect: outcomeText = "Wrong"
            case nil: outcomeText = "Skipped"
            }
            let header = [topicText, levelText, outcomeText, idText]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")

            guard let problem = resolve(entry) else {
                blocks.append(MathBlock(
                    latex: "\\text{Question text unavailable — logged before this export existed.}",
                    label: "\(number). \(header)"
                ))
                continue
            }

            blocks.append(MathBlock(latex: problem.promptLatex, label: "\(number). \(header)"))

            let includesWork = detail.includesWork(for: entry.outcome)
            if includesWork {
                blocks.append(MathBlock(latex: problem.answerLatex, style: .inline, label: "Answer"))
                if detail.includesSteps {
                    for (stepIndex, step) in problem.steps.enumerated() {
                        blocks.append(MathBlock(
                            latex: step.latex,
                            style: .inline,
                            label: "Step \(stepIndex + 1) · \(step.title)"
                        ))
                    }
                }
            }
        }

        let subtitleParts = [
            "\(session.correct)/\(session.attempts) right",
            session.skips > 0 ? "\(session.skips) skipped" : nil
        ].compactMap(\.self)

        return MathDocument(
            title: "Session · \(Self.dateTimeFormatter.string(from: session.startedAt))",
            subtitle: subtitleParts.joined(separator: " · "),
            blocks: blocks,
            workingSpace: 0
        )
    }

    /// Every flagged Key problem, newest first (matching `AppModel.keyProblems`), with its
    /// note printed alongside — the note is the whole point of flagging something Key.
    static func keyProblems(_ records: [KeyProblemRecord], registry: TopicRegistry) -> MathDocument {
        var blocks: [MathBlock] = []
        for (index, record) in records.enumerated() {
            guard let problem = record.problem else { continue }
            let number = index + 1
            let topicText = registry.displayName(for: problem.practiceKey)
            let header = "\(topicText) · Level \(problem.difficulty) · ID \(record.problemID)"
            blocks.append(MathBlock(latex: problem.promptLatex, label: "\(number). \(header)"))
            if !record.note.isEmpty {
                blocks.append(MathBlock(latex: latexText(record.note), style: .inline, label: "Note"))
            }
        }
        return MathDocument(
            title: "Key Problems",
            subtitle: "\(records.count) problem\(records.count == 1 ? "" : "s")",
            blocks: blocks
        )
    }

    /// Wraps free-form user text (a Key note) as a KaTeX `\text{}` block, escaping the
    /// handful of characters that would otherwise be read as LaTeX control sequences.
    private static func latexText(_ raw: String) -> String {
        let escaped = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
        return "\\text{\(escaped)}"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    /// The full HTML page, including the callback that signals render completion.
    ///
    /// KaTeX is invoked with `throwOnError: false` so one malformed block cannot prevent
    /// the page from ever signalling — a page that never signals would hang the export.
    func html() -> String {
        let background = colorScheme == .dark ? "#1c1c1e" : "#ffffff"
        let foreground = colorScheme == .dark ? "#f2f2f7" : "#111111"
        let rule = colorScheme == .dark ? "#3a3a3c" : "#d8d8dc"

        let header = [
            title.map { "<h1>\(Self.escape($0))</h1>" },
            subtitle.map { "<p class=\"subtitle\">\(Self.escape($0))</p>" }
        ]
        .compactMap(\.self)
        .joined(separator: "\n")

        let body = blocks.map { block in
            let label = block.label.map { "<span class=\"label\">\(Self.escape($0))</span>" } ?? ""
            let space = workingSpace > 0 ? "<div class=\"working\"></div>" : ""
            return """
            <section class="block">
              \(label)
              <span class="math-scroll"><span class="math" data-latex="\(Self.escape(block.latex))"
                data-display="\(block.style == .display)"></span></span>
              \(space)
            </section>
            """
        }
        .joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <link rel="stylesheet" href="katex.min.css">
          <style>
            :root { color-scheme: \(colorScheme.rawValue); }
            body {
              margin: 0; padding: 20px 24px;
              background: \(background); color: \(foreground);
              font: 15px -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            }
            h1 { font-size: 20px; margin: 0 0 2px; }
            .subtitle { margin: 0 0 20px; opacity: 0.6; font-size: 13px; }
            .block { margin: 0 0 14px; display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px; }
            .label { font-variant-numeric: tabular-nums; font-weight: 600; opacity: 0.85; min-width: 26px; }
            .math-scroll { flex: 1 1 auto; min-width: 0; overflow-x: auto; overflow-y: hidden; -webkit-overflow-scrolling: touch; }
            .math { font-size: 19px; display: inline-block; }
            .working { flex-basis: 100%; height: \(workingSpace)px; border-bottom: 1px solid \(rule); }
            .katex-error { color: #c0392b; }
          </style>
          <script src="katex.min.js"></script>
        </head>
        <body>
          \(header)
          \(body)
          <script>
            \(Self.renderScript)
          </script>
        </body>
        </html>
        """
    }

    /// The completion callback. Lifted out of `html()` so the page builder stays readable
    /// and so this — the JavaScript half of the render gate — can be read on its own.
    private static let renderScript = """
    (function () {
      var signalled = false;
      function signal(payload) {
        if (signalled) { return; }
        signalled = true;
        window.webkit.messageHandlers.\(MathRenderer.messageHandlerName).postMessage(payload);
      }
      try {
        var nodes = document.querySelectorAll('.math');
        var failures = [];
        for (var i = 0; i < nodes.length; i++) {
          var node = nodes[i];
          katex.render(node.getAttribute('data-latex'), node, {
            displayMode: node.getAttribute('data-display') === 'true',
            throwOnError: false,
            output: 'html'
          });
          if (node.querySelector('.katex-error')) { failures.push(i); }
        }
        // Wait for the bundled faces to be in place before saying the page is done:
        // measuring or printing mid-swap is what produces blank or reflowed output.
        var ready = document.fonts ? document.fonts.ready : Promise.resolve();
        ready.then(function () {
          requestAnimationFrame(function () {
            // Measured after the fonts have swapped in, so the height matches what is
            // actually on screen rather than the pre-KaTeX fallback layout.
            var height = document.body.scrollHeight;
            signal({ status: 'rendered', count: nodes.length, failures: failures, height: height });
          });
        });
      } catch (error) {
        signal({ status: 'failed', message: String(error) });
      }
    })();
    """

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
