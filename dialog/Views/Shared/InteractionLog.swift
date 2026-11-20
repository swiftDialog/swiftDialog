//
//  InteractionLog.swift
//  dialog
//
//  The one interaction-log sink inspect components write user choices
//  through, for orchestrators to tail.
//

import Foundation

/// Canonical interaction-log path tailed by orchestrators; every preset writes it.
let interactionLogPath = "/tmp/swiftdialog_interaction.log"

/// Older path listeners still tail, so every line is dual-written.
let legacyInteractionLogPath = "/tmp/preset6_interaction.log"

/// Append one line to the interaction log (creates the files on first write).
func appendToInteractionLog(_ message: String) {
    let logEntry = "\(message)\n"
    guard let data = logEntry.data(using: .utf8) else { return }

    for path in [interactionLogPath, legacyInteractionLogPath] {
        if FileManager.default.fileExists(atPath: path) {
            if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                _ = try? fileHandle.seekToEnd()
                _ = try? fileHandle.write(contentsOf: data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
