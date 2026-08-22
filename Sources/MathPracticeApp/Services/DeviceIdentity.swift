//  DeviceIdentity.swift
//  A stable per-device identifier, used in the total event ordering and the dedupe key.
//
//  This is the one thing UserDefaults holds that is not a UI preference — and it is still
//  strictly device-local: it never participates in resolving a derived value, it only
//  labels which device appended an event so the ordering can be total.

import Foundation

enum DeviceIdentity {
    private static let key = "com.jsglazer.MathPractice.deviceIdentifier"

    /// The identifier for this device, minted once and then stable.
    static func current(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let minted = UUID().uuidString
        defaults.set(minted, forKey: key)
        return minted
    }
}
