# MathPractice

[![GitHub release](https://img.shields.io/github/v/release/jsglazer/math-practice?logo=github)](https://github.com/jsglazer/math-practice/releases) [![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/jsglazer/math-practice/blob/main/LICENSE) [![Made with Claude](https://img.shields.io/badge/Made_with-Claude-D97756?logo=anthropic)](https://claude.ai) [![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org) [![Gemini Flash Antigravity](https://img.shields.io/badge/Gemini%20Flash-Antigravity-4f86f7?logo=google-gemini&logoColor=white)](https://github.com/google-gemini)

A calculus drill app for macOS and iOS built around working problems **on paper** — not typing answers into a screen.

Pick a topic and a sub-type, get a problem, solve it by hand, then ask for the answer. Separately, ask to see the derivation **one step at a time**. Self-report right or wrong. The app tracks that record per problem type and moves the difficulty up or down accordingly.

Most maths apps are answer-entry quiz engines: they want the answer typed in, they grade it, and they show the solution as one wall of text. MathPractice inverts all three. It never asks for the answer, it gates disclosure behind explicit requests, and it reveals the derivation incrementally so a stuck problem can be unstuck with the smallest possible hint.

## Features

- **Never asks for the answer.** There is no input field anywhere in the app, and no grading. Correctness is a self-reported `Right`/`Wrong` — the app is a drill partner, not an examiner.
- **Incremental reveal, in one selectable pane.** `Show next step` releases exactly one further line of the derivation. `Show answer` releases the answer. Once the answer is out there is nothing left to protect, so a step request then returns the complete worked solution at once — and the answer plus every revealed step render together in one pane, so the whole derivation can be selected and copied in a single drag.
- **Skip, with a note.** A problem that's off-topic today can be skipped instead of worked, with an optional note explaining why — skips are logged and reviewable but never touch the difficulty ladder.
- **Adaptive difficulty, 1–10, per `(topic, sub-type)`.** The chain rule tracks separately from the power rule, because being good at one says nothing about the other.
- **Configurable ladder.** Harder after *N* correct in a row, easier after *M* wrong, with a hold period so one bad patch does not drop you three levels.
- **16 derivative templates** across power, product, quotient, chain, trigonometric, and exponential/logarithmic rules — every one of them verified against SymPy before it ships (see [Correctness](#correctness)). Quotient-rule answers that don't reduce to a closed form by simplification alone (a distributed numerator) are expanded and collected, not left half-factored.
- **Every problem carries a short, stable ID.** Deterministic from `(template, difficulty, seed)`, shown right under the problem and logged with every attempt or skip — enough to reference one exact problem later without the app persisting anything extra for it.
- **Progress matrix and session history.** Topic × sub-type × difficulty, showing where you are strong and where you are not, plus a list of past practice sessions (grouped by a 30-minute gap in activity) you can open and review problem by problem. Every number is folded out of the log on the spot; nothing on that screen is stored beyond the event log itself.
- **PDF worksheets (macOS).** Name a sheet, export it, work it on paper, then come back and click Right/Wrong by question number. The printed numbers and the in-app rows are the same ordinals by construction.
- **Problem-pack import.** Drop in a JSON pack of LLM-authored problems for cases templates handle poorly. Packs sync, are validated wholesale, and are versioned.
- **Multi-device sync via CloudKit.** Two Macs and an iPhone, some online and some not, converge on the same state — see [How sync works](#how-sync-works).

**v1 topic scope is derivatives.** Integrals, limits and advanced algebra are topics 2, 3 and 4, and the app is built so adding one is a new directory plus a single line in `TopicRegistry.standard` — a claim the test suite verifies by registering a topic the app has never heard of and driving the selector, the router, the ladder and the dashboard entirely through it.

## How sync works

The interesting problem in this app is not the maths. It is that two devices, both offline, both being practised on, must not disagree when they reconnect.

The design dissolves the conflict rather than resolving it:

- **The attempt log is a strictly append-only event stream.** Attempts, worksheet self-reports, manual difficulty overrides, and ladder-threshold changes are all events in that one stream. Nothing is ever mutated or deleted after insert.
- **The difficulty level is never stored.** It is computed as a pure, order-independent fold over the event stream, sorted into one total order — `(timestamp, deviceID, eventID)` — that every device agrees on. A synced *mutable* level is the one value two offline devices could legitimately disagree about, so there isn't one.
- **Uniqueness is a value, not a constraint.** SwiftData with CloudKit cannot express a unique constraint, so every syncable record carries a `dedupeKey`: a deterministic digest of its logical identity. A dedup pass runs on every remote change and collapses duplicates.
- **Dedup resolution is order-independent.** The survivor is the record with the earliest `createdAt`, ties broken by the lexicographically smallest UUID string — deliberately *not* wall-clock last-writer-wins, which is not order-independent and lets two devices keep different survivors from the same data.
- **Two stores, two containers.** `Library` holds the read-mostly imported packs; `Log` holds the write-heavy event stream. Disjoint model sets, separate iCloud containers.

## Correctness

There is no computer algebra system in the app. Each template states its own derivative in closed form and assembles it structurally — which raises the obvious question of who checks the closed form.

`Tools/verify_templates/` does, at build time. It runs every template at three difficulties across three fixed seeds, differentiates each generated problem with **SymPy**, and refuses to write the golden fixture unless the template's stated answer is symbolically equal to it *and* the last step of the worked solution lands on that same answer. The Swift suite then asserts the generators still reproduce that fixture byte for byte.

So a template cannot change without the gate being re-run — and `swift test` needs no Python at all. SymPy is never shipped, never a runtime dependency, and never a test dependency.

Generation is seeded end to end: every template and selector takes an injected `RandomNumberGenerator`, core ships a deterministic SplitMix64, and no free call to `.random(in:)`, `.randomElement()` or `.shuffled()` appears anywhere in the core module. A generated problem persists its seed and reproduces byte for byte.

## Architecture

```
Sources/MathPracticeCore/     pure domain logic — no SwiftUI, WebKit, SwiftData, or I/O
  Expressions/                a small exact expression tree + LaTeX and SymPy renderers
  Templates/                  the ProblemTemplate protocol, difficulty scaling, goldens
  Topics/Derivatives/         topic 1: 16 templates across 6 sub-types
  Ladder/                     the adaptive ladder, as a pure fold over the event stream
  Events/                     the append-only event stream and its total ordering
  Dedup/                      dedupe keys and the order-independent survivor rule
  Reveal/                     the disclosure state machine
  Dashboard/                  the progress matrix aggregation
  Sessions/                   groups the event stream into reviewable practice sessions
  Packs/  Worksheets/  Selection/  Random/

Sources/MathPracticeApp/      the OS shell
  Persistence/                SwiftData models and the two-configuration container
  Services/                   event store, dedup service, pack import, app model
  Rendering/                  locally bundled KaTeX in a WKWebView
  Export/macOS/               the only WorksheetExporting conformance
  Export/iOS/                 its counterpart, which returns nil

Tools/verify_templates/       the offline SymPy gate (build-time only, never shipped)
```

`MathPracticeCore` is a Swift package; the macOS and iOS app targets are generated by XcodeGen from `project.yml` and link that library. `swift test` is the headless gate and never needs the app targets.

Maths is typeset by **KaTeX 0.16.22**, bundled locally — the engine, the stylesheet and all twenty `woff2` faces ship inside the app and are served to the web view over a private URL scheme. The rendering path makes no network request of any kind.

PDF export is gated on a callback: the page posts a completion message once `katex.render` has run over every block *and* `document.fonts.ready` has resolved, and that message resolves the single continuation the exporter awaits. There is exactly one such await point in the codebase — not a timeout, and not a polling loop, either of which would be a race dressed up as a fix.

## Building

Requires Xcode 16 or later (built against Xcode 26.6 / Swift 6.3.3) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
# The headless gate — no Xcode project, no Python, no network.
swift test

# Generate the app project, then build either target.
xcodegen generate
xcodebuild -project MathPractice.xcodeproj -scheme MathPractice     -destination 'platform=macOS' build
xcodebuild -project MathPractice.xcodeproj -scheme MathPractice-iOS -destination 'generic/platform=iOS' build
```

To re-run the SymPy gate after changing a template:

```sh
python3 -m venv Tools/verify_templates/.venv
Tools/verify_templates/.venv/bin/pip install -r Tools/verify_templates/requirements.txt
Tools/verify_templates/.venv/bin/python Tools/verify_templates/verify_templates.py
```

Never edit `Tests/MathPracticeCoreTests/Golden/templates.json` by hand — a hand-edited golden is an unverified golden.

## Problem pack format

A pack is a JSON file identified by `(identifier, version)`. Re-importing the same pair is a no-op; a higher version supersedes and *hides* the earlier one without deleting it, because the append-only log still references its problems. A pack is validated wholesale and rejected in full on any single failure.

```json
{
  "identifier": "llm-chain-rule",
  "version": 1,
  "title": "Chain rule, LLM authored",
  "topicID": "derivatives",
  "problems": [
    {
      "index": 0,
      "subTypeID": "chain",
      "difficulty": 6,
      "instruction": "Differentiate with respect to x",
      "promptLatex": "\\sin\\left(x^{2}\\right)",
      "answerLatex": "2 x \\cos\\left(x^{2}\\right)",
      "canonicalPrompt": "sin((x)**(2))",
      "canonicalAnswer": "(2*x*cos((x)**(2)))",
      "steps": [
        { "title": "Apply the chain rule", "latex": "f'(g(x))\\, g'(x)" },
        { "title": "Substitute", "latex": "2 x \\cos\\left(x^{2}\\right)", "canonical": "(2*x*cos((x)**(2)))" }
      ]
    }
  ]
}
```

The `canonical*` fields use the same SymPy-parseable schema the golden fixtures use, so a pack can be put through the same verifier the built-in templates are.

## Platforms

| | macOS 14+ | iOS 17+ |
|---|---|---|
| Practice, reveal loop, self-report | ✅ | ✅ |
| Adaptive ladder, dashboards | ✅ | ✅ |
| Problem-pack import | ✅ | ✅ |
| CloudKit sync | ✅ | ✅ |
| PDF worksheet export | ✅ | — |

PDF export has no iOS conformance to the `WorksheetExporting` protocol, and `Export/macOS/` is excluded from the iOS target's sources — the exporter does not merely go unused there, it is not in the binary.

## Licence

MIT — see [LICENSE](LICENSE).

Bundled KaTeX is © 2013–2020 Khan Academy and contributors, MIT licensed; its licence ships alongside the engine at `Sources/MathPracticeApp/Resources/katex/KATEX-LICENSE`.
