//
//  CommandFileReplayGuard.swift
//  Dialog
//
//  Keeps a previous session's commands from replaying: a command file is append-only and
//  outlives its writer, so a reader adopts the existing content on first look and processes
//  only what arrives afterwards. Used by InspectState's poll of the shared `/var/tmp/dialog.log`.
//

import Foundation

enum CommandFileReplayGuard {

    /// The lines a reader should act on.
    ///
    /// - Parameters:
    ///   - allLines: the file's current non-empty lines.
    ///   - lastProcessedLineCount: how many lines this reader has already accounted for.
    ///   - seeded: whether this reader has looked before; the first look adopts without processing.
    static func linesToProcess(allLines: [String],
                               lastProcessedLineCount: Int,
                               seeded: Bool) -> [String] {
        guard seeded else { return [] }
        return Array(allLines.dropFirst(max(0, lastProcessedLineCount)))
    }
}
