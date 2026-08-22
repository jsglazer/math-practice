//  main.swift
//  Build-time-only: prints the golden sample set as JSON on stdout.
//
//  `Tools/verify_templates/verify_templates.py` runs this, checks every record with SymPy,
//  and only then writes `Tests/MathPracticeCoreTests/Golden/templates.json`. Nothing in the
//  shipped app depends on this target.

import Foundation
import MathPracticeCore

let fixture = GoldenFixture.sample(registry: .standard)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

do {
    let data = try encoder.encode(fixture)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("template dump failed: \(error)\n".utf8))
    exit(1)
}
