//
//  InspectLegacyRemap.swift
//  dialog
//
//  The legacy layer: 3.1.1 keys v6 no longer reads are translated, in memory only, into the v6 keys
//  giving the closest behaviour, or named as having no effect. The admin's file is never touched. Every
//  key gets a note: it is logged once at load and reaches `--inspect-lint` as a warning with the v6
//  replacement. A v6 key set beside the old one wins, and the old one is flagged as redundant.
//
//  Runs before scalar coercion in `validateInspectSchema`, so launch sizing, the loaders and lint see the
//  same config. Pure over the JSON object, so tests drive it directly.
//

import Foundation

enum InspectLegacyRemap {

    struct Result {
        var object: [String: Any]
        /// One line per legacy key: where it was, what it became, and what to write instead.
        var notes: [String]
    }

    static func apply(_ object: [String: Any]) -> Result {
        var root = object
        var notes: [String] = []
        let preset = (root["preset"]).flatMap { InspectPresetName.engine("\($0)") }

        remapSize(&root, preset: preset, notes: &notes)
        if preset == 3 { remapPreset3Backdrop(&root, notes: &notes) }

        for list in ["introSteps", "steps", "items"] {
            guard var entries = root[list] as? [Any] else { continue }
            for i in entries.indices {
                guard var step = entries[i] as? [String: Any] else { continue }
                remapStep(&step, at: "\(list)[\(step["id"] as? String ?? String(i))]", notes: &notes)
                entries[i] = step
            }
            root[list] = entries
        }

        root = (removeBlockKeys(root, path: "", notes: &notes) as? [String: Any]) ?? root
        return Result(object: root, notes: notes)
    }

    /// One step sent at runtime (`step_add`): the step and block rules, logged under `step_add[<id>]`.
    static func apply(step: [String: Any]) -> Result {
        var out = step
        var notes: [String] = []
        let path = "step_add[\(step["id"] as? String ?? "?")]"
        remapStep(&out, at: path, notes: &notes)
        out = (removeBlockKeys(out, path: path, notes: &notes) as? [String: Any]) ?? out
        return Result(object: out, notes: notes)
    }

    // MARK: Root

    /// 3.1.1's window table for the `size` values that differ from v6's own sizes. `standard` and an
    /// unset size match v6 closely, and Presets 1–3 never read `size`, so neither is remapped.
    static let sizeTable: [Int: [String: (width: Int, height: Int)]] = [
        4: ["compact": (480, 100), "large": (600, 130)],
        5: ["compact": (1024, 640), "large": (1200, 800), "assistant": (1024, 700), "portal": (1100, 700)],
        6: ["large": (1100, 700)]
    ]

    private static func remapSize(_ root: inout [String: Any], preset: Int?, notes: inout [String]) {
        guard let mode = (root["size"] as? String)?.lowercased(), let preset else { return }
        if preset == 5, mode == "setup" {
            notes.append("legacy key 'size: setup' (3.1.1): the vertical guide layout it switched to is gone; "
                         + "v6 draws every guide step as a card. Remove the key.")
            return
        }
        guard let size = sizeTable[preset]?[mode] else { return }
        if root["width"] != nil || root["height"] != nil {
            notes.append("legacy key 'size: \(mode)' is redundant: 'width'/'height' are set and win. Remove 'size'.")
            return
        }
        root["width"] = size.width
        root["height"] = size.height
        notes.append("legacy key 'size: \(mode)' remapped → width \(size.width), height \(size.height) (3.1.1 compatibility); "
                     + "content is not scaled as in 3.1.1 (see 'density'). Use \"width\": \(size.width), \"height\": \(size.height) instead.")
    }

    /// Preset 3's 3.1.1 backdrop (`gradientColors`, else `backgroundColor`) becomes the v6 phase backdrop,
    /// a soft wash rather than a solid fill. Its image and text-colour keys have no v6 counterpart.
    private static func remapPreset3Backdrop(_ root: inout [String: Any], notes: inout [String]) {
        let gradient = (root["gradientColors"] as? [String]).flatMap { $0.count >= 2 ? $0 : nil }
        let solid = root["backgroundColor"] as? String
        if let palette = gradient ?? solid.map({ [$0, $0] }) {
            let key = gradient != nil ? "gradientColors" : "backgroundColor"
            if root["phaseBackground"] != nil {
                notes.append("legacy key '\(key)' (Preset 3, 3.1.1) is redundant: 'phaseBackground' is set and wins. Remove '\(key)'.")
            } else {
                root["phaseBackground"] = "gradient"
                if root["phaseBackgroundPalette"] == nil { root["phaseBackgroundPalette"] = palette }
                notes.append("legacy key '\(key)' (Preset 3, 3.1.1) remapped → phaseBackground \"gradient\" tinted with "
                             + "\(palette.joined(separator: ", ")); v6 draws a soft wash, not a solid fill. "
                             + "Use \"phaseBackground\": \"gradient\", \"phaseBackgroundPalette\": \(json(palette)) instead.")
            }
        }
        for key in ["backgroundImage", "backgroundOpacity", "textOverlayColor"] where root[key] != nil {
            notes.append("legacy key '\(key)' (Preset 3, 3.1.1) has no effect in v6: Preset 3 draws its phase backdrop "
                         + "with standard text colours. Remove it, or use 'phaseBackground'.")
        }
    }

    // MARK: Steps

    private static func remapStep(_ step: inout [String: Any], at path: String, notes: inout [String]) {
        rename(&step, "footerLink", to: "footerNote", at: path, notes: &notes,
               detail: "a footer line (Markdown), where 3.1.1 drew link-styled text that did nothing when clicked")
        rename(&step, "guideStepBadge", to: "eyebrow", at: path, notes: &notes,
               detail: "the short chip above the title, shown where the step's layout has one")

        // Key points and bullets: appended to the step's blocks, as `guideText` is (StepCanonicalization).
        let blocksKey = step["content"] == nil && step["guidanceContent"] != nil ? "guidanceContent" : "content"
        if let points = step.removeValue(forKey: "guideKeyPoints") as? String, !points.isEmpty {
            let block: [String: Any] = ["type": "info", "title": "Key Points", "content": points]
            append(block, to: &step, key: blocksKey)
            notes.append("\(path): legacy key 'guideKeyPoints' remapped → a 'Key Points' info block at the end of '\(blocksKey)'. "
                         + "Add \(json(block)) to '\(blocksKey)' instead.")
        }
        if let bullets = step.removeValue(forKey: "guideBulletPoints") as? [String], !bullets.isEmpty {
            let block: [String: Any] = ["type": "bullets", "items": bullets]
            append(block, to: &step, key: blocksKey)
            notes.append("\(path): legacy key 'guideBulletPoints' remapped → a bullets block at the end of '\(blocksKey)'. "
                         + "Add \(json(block)) to '\(blocksKey)' instead.")
        }

        let gone = [
            "guideCategoryIcon": "the badge icon has no v6 counterpart",
            "guideImageRatio": "v6 draws guide steps as cards, without the hero/sidebar split",
            "guideGradientColors": "v6 draws guide steps as cards, without the hero gradient",
            "installationScale": "installation rows are drawn at one size; 'installationLayout' picks list or grid"
        ]
        for (key, why) in gone.sorted(by: { $0.key < $1.key }) where step.removeValue(forKey: key) != nil {
            notes.append("\(path): legacy key '\(key)' (3.1.1) has no effect in v6: \(why). Remove it.")
        }

        // Preset 6's intro/outro styling: 3.1.1 read only the hero size and padding, which are step keys in v6.
        if let layout = step.removeValue(forKey: "introLayoutConfig") as? [String: Any] {
            var moved: [String] = []
            for key in ["heroImageSize", "heroImagePadding"] {
                guard let value = layout[key] else { continue }
                if step[key] == nil { step[key] = value; moved.append("\"\(key)\": \(json(value))") }
            }
            let dead = ["heroImageShape", "logoImage", "logoPosition", "logoMaxWidth"].filter { layout[$0] != nil }
            var note = "\(path): legacy key 'introLayoutConfig' (3.1.1)"
            note += moved.isEmpty ? " has no effect in v6." : " remapped → \(moved.joined(separator: ", ")) on the step."
            if !dead.isEmpty { note += " \(dead.joined(separator: ", ")) never had an effect; root 'logoConfig' places a logo." }
            note += moved.isEmpty ? " Remove it." : " Use those step keys instead."
            notes.append(note)
        }
    }

    // MARK: Blocks

    /// Keys of content blocks and portal blocks that 3.1.1 decoded but never drew, or that v6 drew away.
    static let goneBlockKeys: [String: String] = [
        "portalOfflineMessage": "it was never shown in 3.1.1; a portal step's 'portalConfig.fallbackMessage' is",
        "portalShowHeader": "it was never read in 3.1.1; v6 always shows the source strip",
        "portalShowRefetch": "it was never read in 3.1.1; v6 offers Retry when the page fails",
        "shellTimeout": "it never had an effect: shell actions are not supported",
        "comparisonStyle": "v6 draws comparisons as one table (checks[])"
    ]

    /// These names are unique to blocks, so the whole tree is walked rather than every block path.
    private static func removeBlockKeys(_ value: Any, path: String, notes: inout [String]) -> Any {
        if var dict = value as? [String: Any] {
            for (key, why) in goneBlockKeys.sorted(by: { $0.key < $1.key }) where dict.removeValue(forKey: key) != nil {
                notes.append("\(path.isEmpty ? "" : "\(path): ")legacy key '\(key)' (3.1.1) has no effect in v6: \(why). Remove it.")
            }
            for (key, child) in dict { dict[key] = removeBlockKeys(child, path: path.isEmpty ? key : "\(path).\(key)", notes: &notes) }
            return dict
        }
        if let array = value as? [Any] {
            return array.enumerated().map { removeBlockKeys($1, path: "\(path)[\($0)]", notes: &notes) }
        }
        return value
    }

    // MARK: Helpers

    /// Old key → new key on one object. The new key wins when both are set; the old one is always removed.
    private static func rename(_ dict: inout [String: Any], _ old: String, to new: String, at path: String,
                               notes: inout [String], detail: String) {
        guard let value = dict.removeValue(forKey: old) else { return }
        if dict[new] != nil {
            notes.append("\(path): legacy key '\(old)' is redundant: '\(new)' is set and wins. Remove '\(old)'.")
            return
        }
        dict[new] = value
        notes.append("\(path): legacy key '\(old)' remapped → '\(new)', \(detail). Use \"\(new)\": \(json(value)) instead.")
    }

    private static func append(_ block: [String: Any], to step: inout [String: Any], key: String) {
        var blocks = step[key] as? [Any] ?? []
        blocks.append(block)
        step[key] = blocks
    }

    /// Compact JSON for a lint suggestion.
    static func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else { return "\(value)" }
        return text
    }

    // MARK: Logging

    /// Notes already logged by this process: the schema check runs several times per launch.
    nonisolated(unsafe) private static var logged = Set<String>()
    private static let lock = NSLock()

    /// One log line per note per process.
    static func log(_ notes: [String]) {
        lock.lock(); defer { lock.unlock() }
        for note in notes where logged.insert(note).inserted {
            writeLog("InspectLegacyRemap: \(note)", logLevel: .info)
        }
    }
}
