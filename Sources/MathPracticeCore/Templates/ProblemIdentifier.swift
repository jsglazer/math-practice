//  ProblemIdentifier.swift
//  A short, stable code for one generated problem instance.
//
//  Derived purely from `(templateID, difficulty, seed)` — the same triple that already
//  determines every other field of a `GeneratedProblem` — so the code needs no storage of
//  its own to stay reproducible, and two devices that draw the same problem always agree
//  on its ID.

/// Deterministic short codes for problem instances. Never random: a random ID would break
/// `GoldenFixtureTests` and `DeterminismTests`, which both require `generate()` to return
/// byte-for-byte the same value every time it is called with the same inputs.
enum ProblemIdentifier {
    private static let alphabet = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ") // no I/O — avoids 1/0 confusion

    /// An 8-character code such as `"QK3F7H2A"`, stable for a given `(templateID, difficulty, seed)`.
    static func code(templateID: TemplateID, difficulty: Int, seed: UInt64) -> String {
        var hash = fnv1a("\(templateID.rawValue)|\(difficulty)|\(seed)")
        var characters: [Character] = []
        for _ in 0..<8 {
            characters.append(alphabet[Int(hash % UInt64(alphabet.count))])
            hash /= UInt64(alphabet.count)
        }
        return String(characters)
    }

    /// FNV-1a 64-bit — small, dependency-free, and stable across processes and platforms,
    /// unlike Swift's built-in `Hashable` conformance which is deliberately randomized.
    private static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
