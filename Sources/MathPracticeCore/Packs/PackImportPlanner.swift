//  PackImportPlanner.swift
//  What importing a pack should do, decided before anything touches the store.
//
//  A pack is identified by `(identifier, version)`. Re-importing the same pair is a no-op.
//  A higher version supersedes and hides the earlier one WITHOUT deleting it, because the
//  attempt log references problems from that earlier version and the log is append-only.

/// A pack already present in the library.
public struct InstalledPack: Hashable, Sendable {
    public let identifier: String
    public let version: Int
    public let isHidden: Bool

    public init(identifier: String, version: Int, isHidden: Bool) {
        self.identifier = identifier
        self.version = version
        self.isHidden = isHidden
    }
}

/// What the import should do.
public enum PackImportDecision: Hashable, Sendable {
    /// This exact `(identifier, version)` is already installed. Do nothing.
    case noOp(identifier: String, version: Int)
    /// A new pack, or a new identifier. Install it.
    case install
    /// A newer version of a pack already installed. Install and hide the listed versions.
    case supersede(hiding: [Int])
    /// An older version than the one installed. Refuse rather than silently regress.
    case supersededByNewer(installedVersion: Int)
}

public enum PackImportPlanner {
    /// Decides what to do with `candidate` given what is already installed.
    public static func plan(
        candidate: ProblemPack,
        installed: [InstalledPack]
    ) -> PackImportDecision {
        let sameIdentifier = installed.filter { $0.identifier == candidate.identifier }
        guard !sameIdentifier.isEmpty else { return .install }

        if sameIdentifier.contains(where: { $0.version == candidate.version }) {
            return .noOp(identifier: candidate.identifier, version: candidate.version)
        }

        let highest = sameIdentifier.map(\.version).max() ?? 0
        if candidate.version < highest {
            return .supersededByNewer(installedVersion: highest)
        }

        let toHide = sameIdentifier
            .filter { $0.version < candidate.version && !$0.isHidden }
            .map(\.version)
            .sorted()
        return .supersede(hiding: toHide)
    }
}
