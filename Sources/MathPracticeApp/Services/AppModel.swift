//  AppModel.swift
//  The composition root and the app's observable state.
//
//  Everything derived — the ladder level, the dashboard matrix, the effective ladder
//  configuration — is recomputed here from the event stream and held ONLY in memory. None
//  of it is ever written back to the store, which is what keeps two offline devices from
//  having anything to disagree about.

import Foundation
import MathPracticeCore
import Observation
import SwiftData

@MainActor
@Observable
final class AppModel {
    // MARK: Dependencies

    let registry: TopicRegistry
    let eventStore: EventStore
    let worksheetStore: WorksheetStore
    let packImportService: PackImportService
    let deduplication: DeduplicationService
    /// `nil` on iOS: there is no `WorksheetExporting` conformance there.
    let worksheetExporter: (any WorksheetExporting)?

    // MARK: Derived state (in-memory cache of a pure fold — never persisted)

    private(set) var events: [PracticeEvent] = []
    private(set) var ladder: LadderSnapshot = DifficultyLadder.fold([])
    private(set) var worksheets: [Worksheet] = []

    // MARK: Session state

    var selectedTopic: TopicID?
    var selectedSubType: SubTypeID?
    var useAdaptiveDifficulty = true
    var chosenDifficulty = 3

    private(set) var currentProblem: GeneratedProblem?
    private(set) var revealState = RevealState()
    private(set) var revealedAnswer: String?
    private(set) var revealedSteps: [SolutionStep] = []
    private(set) var lastError: String?

    /// The session's generator. Seeded once so a session is reproducible end to end.
    private var generator: RandomSource

    init(
        registry: TopicRegistry = .standard,
        context: ModelContext,
        deviceID: DeviceID,
        sessionSeed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
    ) {
        self.registry = registry
        self.eventStore = EventStore(context: context, deviceID: deviceID)
        self.worksheetStore = WorksheetStore(context: context)
        self.packImportService = PackImportService(context: context, registry: registry)
        self.deduplication = DeduplicationService(context: context)
        self.worksheetExporter = WorksheetExporterInstaller.make()
        // The session seed is the ONE place a non-deterministic value enters, and it enters
        // the shell — never core, which only ever sees the seed it is handed.
        self.generator = RandomSource(seed: sessionSeed)
        self.selectedTopic = registry.topics.first?.id
    }

    // MARK: - Lifecycle

    func start() {
        deduplication.start()
        reload()
    }

    /// Re-reads the stream and recomputes everything derived from it.
    func reload() {
        events = eventStore.allEvents()
        ladder = DifficultyLadder.fold(events)
        worksheets = worksheetStore.all()
    }

    // MARK: - Derived views

    var configuration: LadderConfiguration { ladder.configuration }

    var practiceKeys: [PracticeKey] { registry.practiceKeys }

    var dashboard: DashboardMatrix {
        DashboardAggregator.aggregate(events: events, keys: practiceKeys, ladder: ladder)
    }

    var sessions: [PracticeSession] {
        SessionAggregator.sessions(from: events)
    }

    var subTypesForSelectedTopic: [SubType] {
        guard let selectedTopic, let topic = registry.topic(selectedTopic) else { return [] }
        return topic.subTypes
    }

    /// The level the ladder would pose next for the current selection.
    var effectiveDifficulty: Int {
        guard useAdaptiveDifficulty else { return chosenDifficulty }
        guard let topic = selectedTopic, let subType = selectedSubType else { return chosenDifficulty }
        return ladder.level(for: PracticeKey(topic: topic, subType: subType))
    }

    // MARK: - Practice loop

    func nextProblem() {
        let request = PracticeRequest(
            topic: selectedTopic,
            subType: selectedSubType,
            difficulty: useAdaptiveDifficulty ? .adaptive : .fixed(chosenDifficulty)
        )
        do {
            currentProblem = try ProblemSelector(registry: registry)
                .next(request, ladder: ladder, using: &generator)
            revealState = RevealState()
            revealedAnswer = nil
            revealedSteps = []
            lastError = nil
        } catch {
            lastError = "No problem available for that selection."
        }
    }

    /// The `a` key: reveal the answer.
    func revealAnswer() {
        apply(.answer)
    }

    /// The `s` key: reveal one further step, or the whole derivation if the answer is out.
    func revealStep() {
        apply(.step)
    }

    private func apply(_ request: RevealRequest) {
        guard let currentProblem else { return }
        let machine = RevealMachine(problem: currentProblem)
        let result = machine.apply(request, to: revealState)
        revealState = result.state

        switch result.output {
        case let .answer(latex):
            revealedAnswer = latex
        case let .step(_, step):
            revealedSteps.append(step)
        case let .allSteps(steps):
            revealedSteps = steps
        case .noFurtherSteps:
            break
        }
    }

    var canRevealMoreSteps: Bool {
        guard let currentProblem else { return false }
        return revealState.answerShown || revealState.stepsShown < currentProblem.steps.count
    }

    /// Records the self-reported result and moves on. Correctness is never computed.
    func record(_ outcome: AttemptOutcome) {
        guard let currentProblem else { return }
        eventStore.recordAttempt(outcome, problem: currentProblem)
        reload()
        nextProblem()
    }

    /// Logs a skip — with an optional note — and moves on without ever asking for an answer.
    func skip(note: String?) {
        guard let currentProblem else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        eventStore.recordSkip(problem: currentProblem, note: trimmed?.isEmpty == false ? trimmed : nil)
        reload()
        nextProblem()
    }

    // MARK: - Settings

    func updateConfiguration(_ configuration: LadderConfiguration) {
        guard configuration.clamped != ladder.configuration else { return }
        eventStore.recordLadderConfiguration(configuration)
        reload()
    }

    func pinLevel(_ level: Int, for key: PracticeKey) {
        eventStore.recordManualLevel(level, for: key)
        reload()
    }

    // MARK: - Worksheets

    /// Freezes a worksheet. Always called before any rendering: the PDF reads the record.
    @discardableResult
    func createWorksheet(name: String, questionCount: Int) -> Worksheet? {
        let request = PracticeRequest(
            topic: selectedTopic,
            subType: selectedSubType,
            difficulty: useAdaptiveDifficulty ? .adaptive : .fixed(chosenDifficulty)
        )
        let selector = ProblemSelector(registry: registry)
        do {
            let problems = try (0..<questionCount).map { _ in
                try selector.next(request, ladder: ladder, using: &generator)
            }
            let worksheet = try worksheetStore.persist(name: name, problems: problems)
            reload()
            return worksheet
        } catch {
            lastError = "Could not create the worksheet: \(error.localizedDescription)"
            return nil
        }
    }

    func exportWorksheet(_ worksheet: Worksheet, to url: URL) async {
        guard let worksheetExporter else { return }
        do {
            try await worksheetExporter.export(worksheet: worksheet, to: url)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func recordWorksheetResults(_ worksheet: Worksheet, outcomes: [Int: AttemptOutcome]) {
        guard !outcomes.isEmpty else { return }
        eventStore.recordWorksheetSelfReport(worksheet: worksheet, outcomes: outcomes)
        reload()
    }

    // MARK: - Packs

    func importPack(at url: URL) -> String {
        do {
            let result = try packImportService.importPack(at: url)
            reload()
            switch result {
            case let .installed(identifier, version, problems):
                return "Imported \(identifier) v\(version) — \(problems) problems."
            case let .superseded(identifier, version, problems, hidden):
                let hiddenText = hidden.map(String.init).joined(separator: ", ")
                return "Imported \(identifier) v\(version) — \(problems) problems. Hid v\(hiddenText)."
            case let .alreadyInstalled(identifier, version):
                return "\(identifier) v\(version) is already installed."
            case let .refusedOlderVersion(identifier, installedVersion):
                return "Refused: \(identifier) v\(installedVersion) is already installed."
            }
        } catch {
            return error.localizedDescription
        }
    }
}
