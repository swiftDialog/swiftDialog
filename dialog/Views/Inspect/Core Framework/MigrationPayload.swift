//
//  MigrationPayload.swift
//  dialog
//
//  How an authored migration step is read into a migration body payload.
//

import SwiftUI

// MARK: - Reading an authored step into a body's payload

/// Pure builders from authored blocks to body payloads, testable without a window.
enum MigrationPayload {

    /// Facts panel contents from a `stat-row`. The first stat becomes the large figure; the rest stay small.
    static func facts(from blocks: [InspectConfig.GuidanceContent]) -> [MigrationFact] {
        let cells = blocks.compactMap(\.stats).flatMap { $0 }
        return cells.enumerated().map { index, cell in
            MigrationFact(id: "\(index)-\(cell.label)", label: cell.label,
                          value: cell.value, isFigure: index == 0)
        }
    }

    /// State rows from a `checklist` or `bullets`. A "check" marker means done; anything else is pending.
    /// `hint` becomes the row's detail, marked as prose so it is not drawn in mono.
    static func rows(from blocks: [InspectConfig.GuidanceContent]) -> [ProvisioningRowModel] {
        var out: [ProvisioningRowModel] = []
        for block in blocks {
            if let lines = block.checklist {
                for (index, line) in lines.enumerated() {
                    out.append(ProvisioningRowModel(
                        id: "\(block.type)-\(index)-\(line.text)",
                        name: line.text,
                        detail: line.hint,
                        detailIsMachine: false,
                        mark: line.marker?.lowercased() == "check" ? .done : .queued))
                }
            } else if let items = block.items {
                for (index, item) in items.enumerated() {
                    out.append(ProvisioningRowModel(
                        id: "\(block.type)-\(index)-\(item)",
                        name: item, detail: nil, detailIsMachine: false, mark: .queued))
                }
            }
        }
        return out
    }

    /// Numbered actions, from the same source as the rows. The number comes from position, never the copy.
    static func actionSteps(from blocks: [InspectConfig.GuidanceContent]) -> [MigrationActionStep] {
        var out: [MigrationActionStep] = []
        for block in blocks {
            if let lines = block.checklist {
                out += lines.enumerated().map { MigrationActionStep(id: "\($0.offset)-\($0.element.text)",
                                                                    text: $0.element.text) }
            } else if let items = block.items {
                out += items.enumerated().map { MigrationActionStep(id: "\($0.offset)-\($0.element)",
                                                                    text: $0.element) }
            }
        }
        return out
    }

    /// The walkthrough URL from the first media block. `normalized` first, since the path may be in `text`;
    /// schemeless paths are read as files.
    static func mediaURL(from blocks: [InspectConfig.GuidanceContent]) -> URL? {
        for raw in blocks {
            let block = InspectConfig.GuidanceContent.normalized(raw)
            guard GuidanceBlockRole(blockType: block.type) == .media,
                  let path = block.content, !path.isEmpty else { continue }
            if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// The wait screen's phase name, from the progress block's own text; the single place it is read.
    static func phase(from blocks: [InspectConfig.GuidanceContent]) -> String? {
        for raw in blocks {
            let block = InspectConfig.GuidanceContent.normalized(raw)
            guard block.type == "progress-bar",
                  let text = block.content, !text.isEmpty else { continue }
            return text
        }
        return nil
    }

    /// The wait screen's substep count and bar fill. The count comes from the progress block's caption
    /// ("3 of 5") and the fraction is derived from it when it parses. Without a caption the bar keeps
    /// the shell's default fraction.
    static func waitProgress(from blocks: [InspectConfig.GuidanceContent])
    -> (count: String?, fraction: Double) {
        // Match the block type: the `.state` role also covers `phase-tracker` and `status-badge`.
        let caption = blocks.first { $0.type == "progress-bar" }?.caption
        guard let caption else { return (nil, 0.45) }
        let numbers = caption.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 2, numbers[1] > 0 else { return (caption, 0.45) }
        return (caption, min(max(Double(numbers[0]) / Double(numbers[1]), 0), 1))
    }

    /// The caption authored under a block, if any.
    static func caption(from blocks: [InspectConfig.GuidanceContent], role: GuidanceBlockRole) -> String? {
        blocks.first { GuidanceBlockRole(blockType: $0.type) == role }?.caption
    }
}

