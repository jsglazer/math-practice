//  DedupeKey.swift
//  Deterministic digests of logical identity.
//
//  SwiftData with CloudKit cannot express a unique constraint, so uniqueness is a value
//  every syncable record carries and the dedup pass enforces. These strings are persisted
//  and compared across devices, so their format is a data contract.

import Foundation

/// Builders for the `dedupeKey` every syncable record carries.
public enum DedupeKey {
    /// Separator chosen because none of the component values can contain it.
    static let separator = "|"

    /// An event: kind, the device that appended it, and that device's monotonic ordinal.
    public static func event(kind: String, deviceID: DeviceID, ordinal: Int) -> String {
        ["event", kind, deviceID.rawValue, String(ordinal)].joined(separator: separator)
    }

    /// A worksheet question: the worksheet's UUID plus the question index.
    public static func worksheetQuestion(worksheetID: UUID, questionIndex: Int) -> String {
        ["worksheet-question", worksheetID.uuidString, String(questionIndex)].joined(separator: separator)
    }

    /// A worksheet itself.
    public static func worksheet(worksheetID: UUID) -> String {
        ["worksheet", worksheetID.uuidString].joined(separator: separator)
    }

    /// An imported pack: identifier plus version.
    public static func pack(identifier: String, version: Int) -> String {
        ["pack", identifier, String(version)].joined(separator: separator)
    }

    /// A problem inside an imported pack: pack identifier, version, and problem index.
    public static func packProblem(identifier: String, version: Int, problemIndex: Int) -> String {
        ["pack-problem", identifier, String(version), String(problemIndex)].joined(separator: separator)
    }
}
