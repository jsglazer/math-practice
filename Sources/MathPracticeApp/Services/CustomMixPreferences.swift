//  CustomMixPreferences.swift
//  Remembers the last "custom mix" checkbox selection and difficulty across launches.
//
//  Local UI convenience only, unlike the difficulty ladder — never synced, never recorded
//  as an event, so two devices are free to remember different custom mixes.

import Foundation
import MathPracticeCore

enum CustomMixPreferences {
    private static let keysDefaultsKey = "customMix.selectedKeys"
    private static let difficultyDefaultsKey = "customMix.difficulty"

    static func loadSelectedKeys() -> Set<PracticeKey>? {
        guard let raw = UserDefaults.standard.array(forKey: keysDefaultsKey) as? [String] else { return nil }
        let keys = raw.compactMap { encoded -> PracticeKey? in
            let parts = encoded.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return PracticeKey(topic: TopicID(String(parts[0])), subType: SubTypeID(String(parts[1])))
        }
        return keys.isEmpty ? nil : Set(keys)
    }

    static func saveSelectedKeys(_ keys: Set<PracticeKey>) {
        let raw = keys.map { "\($0.topic.rawValue)|\($0.subType.rawValue)" }
        UserDefaults.standard.set(raw, forKey: keysDefaultsKey)
    }

    /// `nil` means "nothing saved yet" — 0 is not a valid difficulty level, so it doubles
    /// as the not-found sentinel `UserDefaults.integer(forKey:)` returns.
    static func loadDifficulty() -> Int? {
        let value = UserDefaults.standard.integer(forKey: difficultyDefaultsKey)
        return value == 0 ? nil : value
    }

    static func saveDifficulty(_ level: Int) {
        UserDefaults.standard.set(level, forKey: difficultyDefaultsKey)
    }
}
