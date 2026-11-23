//  ActivityWatchHeartbeat.swift
//  What MathPractice tells a local ActivityWatch server, and when — with no network code.
//
//  ActivityWatch merges a heartbeat into the previous event when its data is identical and
//  it arrives within `pulsetime` of that event's end. So while the context stays the same,
//  one heartbeat every `interval` seconds keeps a single growing event; when the context
//  changes, the old event is first extended to the moment of the change and the new context
//  starts a new event at that same moment, so consecutive events meet without a gap.
//
//  The HTTP client that actually sends these lives in the macOS app target. Everything here
//  is pure so the payload and the "send now?" decision are unit-testable headlessly.

import Foundation

/// The app tab a heartbeat was sent from. Raw values are what the `tab` field carries.
public enum ActivityTab: String, Sendable, CaseIterable {
    case practice = "Practice"
    case progress = "Progress"
    case sessions = "Sessions"
    case key = "Key"
    case worksheets = "Worksheets"
    case settings = "Settings"

    /// What kind of work the tab is: drilling, worksheets, or looking back over past work.
    public var mode: ActivityMode {
        switch self {
        case .practice, .settings: return .practice
        case .worksheets: return .worksheet
        case .progress, .sessions, .key: return .review
        }
    }
}

/// The `mode` field.
public enum ActivityMode: String, Sendable, CaseIterable {
    case practice
    case worksheet
    case review
}

/// Everything one heartbeat reports. Two contexts are equal exactly when ActivityWatch
/// should treat them as the same ongoing event.
public struct ActivityContext: Hashable, Sendable {
    public var className: String
    public var tab: ActivityTab
    public var topic: String
    public var subtype: String
    public var level: Int?
    public var problem: String

    public init(className: String, tab: ActivityTab, topic: String, subtype: String, level: Int?, problem: String) {
        self.className = className
        self.tab = tab
        self.topic = topic
        self.subtype = subtype
        self.level = level
        self.problem = problem
    }

    public var mode: ActivityMode { tab.mode }

    /// The event's `data` object. Every value is a string; an absent value is `""`.
    public var data: [String: String] {
        [
            "class": className,
            "tab": tab.rawValue,
            "topic": topic,
            "subtype": subtype,
            "level": level.map(String.init) ?? "",
            "problem": problem,
            "mode": mode.rawValue
        ]
    }
}

/// Builds an `ActivityContext` from the app's current selection, applying the naming rules
/// (custom mix, random mix, class resolution) in one tested place.
public enum ActivityContextBuilder {
    public static let customMixTopic = "custom mix"
    public static let randomMix = "random mix"

    /// What the user has selected to practise.
    public enum Selection: Sendable, Equatable {
        /// The topic / sub-type pickers. `nil` display names mean "Random mix".
        case pickers(topic: String?, subtype: String?)
        /// Custom mix on: the checked sub-types' display names, in a stable order.
        case customMix(subtypes: [String])
    }

    public static func make(
        tab: ActivityTab,
        selection: Selection,
        level: Int?,
        problemID: String?,
        className: String
    ) -> ActivityContext {
        let topic: String
        let subtype: String
        switch selection {
        case let .pickers(topicName, subtypeName):
            topic = topicName ?? randomMix
            subtype = subtypeName ?? randomMix
        case let .customMix(subtypes):
            topic = customMixTopic
            subtype = subtypes.joined(separator: ", ")
        }
        return ActivityContext(
            className: className,
            tab: tab,
            topic: topic,
            subtype: subtype,
            level: level,
            problem: problemID ?? ""
        )
    }
}

/// How the class a piece of work counts toward is chosen.
///
/// A tag is `String?`: `nil` means "not tagged — use the next fallback", `""` means
/// "deliberately no class", and any other value is a class name spelled exactly as the
/// Classes dashboard names it.
public enum ActivityClass {
    /// The worksheet's tag wins, then the practice session's, then the per-Mac default.
    public static func resolve(worksheetTag: String?, sessionTag: String?, defaultClass: String) -> String {
        if let worksheetTag { return worksheetTag }
        if let sessionTag { return sessionTag }
        return defaultClass
    }

    /// Pre-filled on first launch; must match the class folder names under
    /// `~/VaultSchar/Classes/<term>/`.
    public static let defaultClassName = "Data - POGO 511"
    public static let seedClassNames = ["Data - POGO 511", "Econ - PUBP 720", "RD - POGO 801"]
}

/// ActivityWatch REST shapes: bucket name, query strings and JSON bodies.
public enum ActivityWatchAPI {
    public static let bucketPrefix = "aw-watcher-mathpractice_"
    public static let eventType = "app.mathpractice.activity"
    public static let client = "math-practice"
    public static let defaultServer = "http://127.0.0.1:5600"
    public static let defaultInterval: TimeInterval = 30

    public static func bucketID(hostname: String) -> String {
        bucketPrefix + hostname
    }

    /// Two intervals, so one late heartbeat (a busy main thread, a slow request) doesn't
    /// split the event.
    public static func pulsetime(interval: TimeInterval) -> TimeInterval {
        2 * interval
    }

    /// `pulsetime` formatted for the query string: no trailing `.0` on whole seconds.
    public static func pulsetimeQuery(interval: TimeInterval) -> String {
        let value = pulsetime(interval: interval)
        return value == value.rounded() ? String(Int(value)) : String(value)
    }

    public static func bucketBody(hostname: String) -> [String: String] {
        ["client": client, "type": eventType, "hostname": hostname]
    }

    public static func heartbeatBody(_ heartbeat: Heartbeat) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body: [String: Any] = [
            "timestamp": formatter.string(from: heartbeat.timestamp),
            "duration": 0,
            "data": heartbeat.context.data
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
}

public struct Heartbeat: Hashable, Sendable {
    public let timestamp: Date
    public let context: ActivityContext

    public init(timestamp: Date, context: ActivityContext) {
        self.timestamp = timestamp
        self.context = context
    }
}

/// Decides when to send a heartbeat. Holds only the last context and when it was last sent.
public struct HeartbeatTracker: Sendable {
    public let interval: TimeInterval
    public private(set) var current: ActivityContext?
    private var lastSent: Date?

    public init(interval: TimeInterval = ActivityWatchAPI.defaultInterval) {
        precondition(interval > 0, "interval must be positive")
        self.interval = interval
    }

    /// Reports the current context — `nil` when MathPractice is not the active app — at
    /// `now`, and returns the heartbeats to send (zero, one, or two).
    public mutating func update(_ context: ActivityContext?, now: Date) -> [Heartbeat] {
        if context == current {
            guard let context, let lastSent else { return [] }
            guard now.timeIntervalSince(lastSent) >= interval else { return [] }
            self.lastSent = now
            return [Heartbeat(timestamp: now, context: context)]
        }

        var out: [Heartbeat] = []
        if let current {
            // Close the old event at the moment of the change.
            out.append(Heartbeat(timestamp: now, context: current))
        }
        if let context {
            out.append(Heartbeat(timestamp: now, context: context))
        }
        current = context
        lastSent = context == nil ? nil : now
        return out
    }
}
