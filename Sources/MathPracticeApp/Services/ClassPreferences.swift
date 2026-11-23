//  ClassPreferences.swift
//  The class list, the per-device Default class, the practice session's class tag, and the
//  ActivityWatch switch and server URL.
//
//  All of it lives in local UserDefaults — never the event log, never CloudKit. The only
//  class data that syncs is a worksheet's own tag, which is stored on its `WorksheetRecord`.

import Foundation
import MathPracticeCore

enum ClassPreferences {
    private static let classNamesKey = "classes.names"
    private static let defaultClassKey = "classes.default"
    private static let sessionClassKey = "classes.session"
    private static let activityWatchEnabledKey = "activityWatch.enabled"
    private static let activityWatchServerKey = "activityWatch.server"

    private static var defaults: UserDefaults { .standard }

    /// The classes offered in every class picker, pre-filled on first launch.
    static func loadClassNames() -> [String] {
        (defaults.array(forKey: classNamesKey) as? [String]) ?? ActivityClass.seedClassNames
    }

    static func saveClassNames(_ names: [String]) {
        defaults.set(names, forKey: classNamesKey)
    }

    /// The class untagged work counts toward on this device. `""` means no class.
    static func loadDefaultClass() -> String {
        defaults.string(forKey: defaultClassKey) ?? ActivityClass.defaultClassName
    }

    static func saveDefaultClass(_ name: String) {
        defaults.set(name, forKey: defaultClassKey)
    }

    /// The Practice tab's class tag: `nil` = use the Default class, `""` = no class.
    static func loadSessionClass() -> String? {
        defaults.string(forKey: sessionClassKey)
    }

    static func saveSessionClass(_ tag: String?) {
        if let tag {
            defaults.set(tag, forKey: sessionClassKey)
        } else {
            defaults.removeObject(forKey: sessionClassKey)
        }
    }

    /// On by default.
    static func loadActivityWatchEnabled() -> Bool {
        defaults.object(forKey: activityWatchEnabledKey) as? Bool ?? true
    }

    static func saveActivityWatchEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: activityWatchEnabledKey)
    }

    static func loadActivityWatchServer() -> String {
        defaults.string(forKey: activityWatchServerKey) ?? ActivityWatchAPI.defaultServer
    }

    static func saveActivityWatchServer(_ server: String) {
        defaults.set(server, forKey: activityWatchServerKey)
    }
}
