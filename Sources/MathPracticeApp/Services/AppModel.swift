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
    let keyProblemStore: KeyProblemStore
    let packImportService: PackImportService
    let deduplication: DeduplicationService
    /// `nil` on iOS: there is no `WorksheetExporting` conformance there.
    let worksheetExporter: (any WorksheetExporting)?
    /// `nil` on iOS: there is no `SessionExporting` conformance there.
    let sessionExporter: (any SessionExporting)?
    /// `nil` on iOS: there is no `KeyExporting` conformance there.
    let keyExporter: (any KeyExporting)?
    /// Heartbeats to the local ActivityWatch server. A no-op on iOS (`ActivityWatch/iOS`).
    let activityWatch = ActivityWatchService()

    // MARK: Derived state (in-memory cache of a pure fold — never persisted)

    private(set) var events: [PracticeEvent] = []
    private(set) var ladder: LadderSnapshot = DifficultyLadder.fold([])
    private(set) var worksheets: [Worksheet] = []
    private(set) var keyProblems: [KeyProblemRecord] = []
    /// Every note-bearing record, starred or not — separate from `keyProblems` (which is
    /// starred-only) so a note on an unstarred problem still shows up where it was typed.
    private(set) var noteRecords: [KeyProblemRecord] = []
    /// Worksheet class tags by worksheet ID (synced on the record; untagged = absent).
    private(set) var worksheetClassTags: [UUID: String] = [:]

    // MARK: Classes and ActivityWatch (local preferences — never the event log or CloudKit)

    /// The classes every class picker offers, spelled exactly as the Classes dashboard does.
    private(set) var classNames: [String]
    /// What untagged work counts toward on this device. `""` = no class.
    private(set) var defaultClassName: String
    /// The Practice tab's class: `nil` = use the Default class, `""` = no class.
    private(set) var sessionClassTag: String?
    private(set) var activityWatchEnabled: Bool
    private(set) var activityWatchServer: String

    /// Which tab is on screen and which worksheet (if any) is open — what the heartbeat reports.
    var activeTab: ActivityTab = .practice
    var openWorksheetID: UUID?

    // MARK: Session state

    var selectedTopic: TopicID?
    var selectedSubType: SubTypeID?
    var useAdaptiveDifficulty = true
    var chosenDifficulty = 3

    /// When on, `nextProblem()`/`createWorksheet()` draw a fresh random `(topic, sub-type)`
    /// from `customMixSelectedKeys` per problem instead of using the pickers above.
    private(set) var customMixEnabled = false
    private(set) var customMixSelectedKeys: Set<PracticeKey>
    private(set) var customMixDifficulty: Int

    private(set) var currentProblem: GeneratedProblem?
    private(set) var revealState = RevealState()
    private(set) var revealedAnswer: String?
    private(set) var revealedSteps: [SolutionStep] = []
    /// "Hide steps": the revealed answer and steps stay revealed but are folded away until
    /// asked for again, so the problem can be re-attempted from a clean screen.
    private(set) var solutionHidden = false
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
        self.keyProblemStore = KeyProblemStore(context: context)
        self.packImportService = PackImportService(context: context, registry: registry)
        self.deduplication = DeduplicationService(context: context)
        self.worksheetExporter = WorksheetExporterInstaller.make()
        self.sessionExporter = SessionExporterInstaller.make()
        self.keyExporter = KeyExporterInstaller.make()
        // The session seed is the ONE place a non-deterministic value enters, and it enters
        // the shell — never core, which only ever sees the seed it is handed.
        self.generator = RandomSource(seed: sessionSeed)
        self.selectedTopic = registry.topics.first?.id
        self.customMixSelectedKeys = CustomMixPreferences.loadSelectedKeys() ?? Set(registry.practiceKeys)
        self.customMixDifficulty = CustomMixPreferences.loadDifficulty() ?? 3
        self.classNames = ClassPreferences.loadClassNames()
        self.defaultClassName = ClassPreferences.loadDefaultClass()
        self.sessionClassTag = ClassPreferences.loadSessionClass()
        self.activityWatchEnabled = ClassPreferences.loadActivityWatchEnabled()
        self.activityWatchServer = ClassPreferences.loadActivityWatchServer()
    }

    // MARK: - Lifecycle

    func start() {
        deduplication.start()
        reload()
        activityWatch.start(
            context: { [weak self] in self?.activityContext },
            isEnabled: { [weak self] in self?.activityWatchEnabled ?? false },
            server: { [weak self] in self?.activityWatchServer ?? ActivityWatchAPI.defaultServer }
        )
    }

    /// Re-reads the stream and recomputes everything derived from it.
    func reload() {
        events = eventStore.allEvents()
        ladder = DifficultyLadder.fold(events)
        worksheets = worksheetStore.all()
        keyProblems = keyProblemStore.all()
        noteRecords = keyProblemStore.allRecords()
        worksheetClassTags = worksheetStore.classTags()
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

    /// Regenerates the exact problem instance `entry` was posed with, when enough was
    /// captured to do so — `nil` for entries logged before problems carried a `seed`.
    func regenerate(_ entry: SessionEntry) -> GeneratedProblem? {
        guard let templateID = entry.templateID,
              let key = entry.key,
              let difficulty = entry.difficulty,
              let seed = entry.seed,
              let resolved = registry.resolve(templateID) else { return nil }
        return resolved.template.generate(topicID: key.topic, difficulty: difficulty, seed: seed)
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

    /// When custom mix is active, draws a fresh random `(topic, sub-type)` from the checked
    /// set for every problem — so a session (or worksheet) actually mixes sub-types rather
    /// than pinning one for its whole duration — at the mix's chosen fixed difficulty.
    /// Otherwise falls back to the ordinary topic/sub-type pickers.
    private func nextPracticeRequest() -> PracticeRequest {
        if customMixEnabled, let key = generator.drawElement(from: sortedCustomMixKeys) {
            return PracticeRequest(topic: key.topic, subType: key.subType, difficulty: .fixed(customMixDifficulty))
        }
        return PracticeRequest(
            topic: selectedTopic,
            subType: selectedSubType,
            difficulty: useAdaptiveDifficulty ? .adaptive : .fixed(chosenDifficulty)
        )
    }

    /// Sorted so a session seed still replays the same problem sequence — `Set` iteration
    /// order is not guaranteed stable across runs.
    private var sortedCustomMixKeys: [PracticeKey] {
        customMixSelectedKeys.sorted {
            ($0.topic.rawValue, $0.subType.rawValue) < ($1.topic.rawValue, $1.subType.rawValue)
        }
    }

    /// Turns on custom mix with `keys` (must be non-empty) and `difficulty`, and remembers
    /// both for next time the picker opens — including across launches.
    func applyCustomMix(keys: Set<PracticeKey>, difficulty: Int) {
        guard !keys.isEmpty else { return }
        customMixSelectedKeys = keys
        customMixDifficulty = DifficultyLadder.clamp(difficulty)
        customMixEnabled = true
        CustomMixPreferences.saveSelectedKeys(keys)
        CustomMixPreferences.saveDifficulty(customMixDifficulty)
        resetProblemAfterSelectionChange()
    }

    /// Turns custom mix off and returns to the ordinary pickers. The checked set and
    /// difficulty stay remembered so reopening the picker starts from where it left off.
    func clearCustomMix() {
        customMixEnabled = false
        resetProblemAfterSelectionChange()
    }

    /// The problem on screen was drawn from the old selection, so after the mix changes it is
    /// replaced (unlogged — it was never attempted under the new mix) with one from the new.
    private func resetProblemAfterSelectionChange() {
        guard currentProblem != nil else { return }
        nextProblem()
    }

    func nextProblem() {
        do {
            currentProblem = try ProblemSelector(registry: registry)
                .next(nextPracticeRequest(), ladder: ladder, using: &generator)
            revealState = RevealState()
            revealedAnswer = nil
            revealedSteps = []
            solutionHidden = false
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
        solutionHidden = false

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

    /// Folds the revealed answer and steps away, or brings them back.
    func toggleSolutionHidden() {
        solutionHidden.toggle()
    }

    var hasRevealedSolution: Bool {
        revealedAnswer != nil || !revealedSteps.isEmpty
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

    // MARK: - Key problems

    /// Reads `keyProblems` — the in-memory, `@Observable`-tracked cache — rather than hitting
    /// `keyProblemStore` directly. A SwiftData fetch isn't an observable property access, so a
    /// view that only ever called into the store here would never be told to re-render when a
    /// flag changed: the star would silently go stale until something unrelated forced a redraw.
    func isKey(_ problemID: String?) -> Bool {
        guard let problemID else { return false }
        return keyProblems.contains { $0.problemID == problemID }
    }

    /// A problem's note, whether or not it's starred Key.
    func keyNote(for problemID: String) -> String? {
        noteRecords.first { $0.problemID == problemID }?.note
    }

    /// Flags `problem` if it isn't already Key, or un-flags it if it is. Un-flagging keeps
    /// any note that was taken on it — only the star comes off.
    func toggleKey(for problem: GeneratedProblem) {
        if keyProblemStore.isFlagged(problem.problemID) {
            keyProblemStore.unflag(problem.problemID)
        } else {
            keyProblemStore.flag(problem)
        }
        reload()
    }

    /// Saves a note against `problem`, whether or not it's starred Key.
    func setNote(_ note: String, for problem: GeneratedProblem) {
        keyProblemStore.setNote(note, for: problem)
        reload()
    }

    func removeKey(_ problemID: String) {
        keyProblemStore.unflag(problemID)
        reload()
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
    func createWorksheet(name: String, questionCount: Int, className: String? = nil) -> Worksheet? {
        let selector = ProblemSelector(registry: registry)
        do {
            let problems = try (0..<questionCount).map { _ in
                try selector.next(nextPracticeRequest(), ladder: ladder, using: &generator)
            }
            let worksheet = try worksheetStore.persist(name: name, problems: problems, className: className)
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

    func exportSession(_ session: PracticeSession, detail: SessionExportDetail, to url: URL) async {
        guard let sessionExporter else { return }
        do {
            try await sessionExporter.export(
                session: session,
                registry: registry,
                detail: detail,
                resolve: regenerate,
                to: url
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportKeyProblems(to url: URL) async {
        guard let keyExporter else { return }
        do {
            try await keyExporter.export(keyProblems: keyProblems, registry: registry, to: url)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Classes

    func worksheetClassTag(_ worksheetID: UUID) -> String? {
        worksheetClassTags[worksheetID]
    }

    func setWorksheetClassTag(_ className: String?, for worksheetID: UUID) {
        worksheetStore.setClassTag(className, for: worksheetID)
        reload()
    }

    func setSessionClassTag(_ tag: String?) {
        sessionClassTag = tag
        ClassPreferences.saveSessionClass(tag)
    }

    func setDefaultClassName(_ name: String) {
        defaultClassName = name
        ClassPreferences.saveDefaultClass(name)
    }

    /// Adds a class name (trimmed; ignored if blank or already listed).
    func addClassName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !classNames.contains(trimmed) else { return }
        classNames.append(trimmed)
        ClassPreferences.saveClassNames(classNames)
    }

    /// Removes a class from the pickers. Existing tags that use it are left alone — the
    /// pickers still show a tag that is no longer listed, so nothing is silently re-tagged.
    func removeClassNames(at offsets: IndexSet) {
        classNames.remove(atOffsets: offsets)
        ClassPreferences.saveClassNames(classNames)
    }

    func setActivityWatchEnabled(_ enabled: Bool) {
        activityWatchEnabled = enabled
        ClassPreferences.saveActivityWatchEnabled(enabled)
    }

    func setActivityWatchServer(_ server: String) {
        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        activityWatchServer = trimmed.isEmpty ? ActivityWatchAPI.defaultServer : trimmed
        ClassPreferences.saveActivityWatchServer(activityWatchServer)
    }

    /// The class the work on screen counts toward right now.
    var activeClassName: String {
        let worksheetTag = activeTab == .worksheets ? openWorksheetID.flatMap(worksheetClassTag) : nil
        return ActivityClass.resolve(worksheetTag: worksheetTag, sessionTag: sessionClassTag, defaultClass: defaultClassName)
    }

    /// What the ActivityWatch heartbeat reports for the screen as it is now.
    var activityContext: ActivityContext {
        let selection: ActivityContextBuilder.Selection
        let level: Int
        if customMixEnabled {
            selection = .customMix(subtypes: sortedCustomMixKeys.map { registry.displayName(for: $0) })
            level = customMixDifficulty
        } else {
            let topic = selectedTopic.flatMap { registry.topic($0) }
            let subType = selectedSubType.flatMap { id in topic?.subTypes.first { $0.id == id } }
            selection = .pickers(topic: topic?.displayName, subtype: subType?.displayName)
            level = effectiveDifficulty
        }
        return ActivityContextBuilder.make(
            tab: activeTab,
            selection: selection,
            level: level,
            problemID: activeTab == .practice ? currentProblem?.problemID : nil,
            className: activeClassName
        )
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
