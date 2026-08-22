//  PlatformClipboard.swift
//  Copying text to the system pasteboard. Kept out of `Views/` — the architecture suite bans
//  `#if os(` there, the same folder-based platform gate `Export/` uses for PDF export.

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PlatformClipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
