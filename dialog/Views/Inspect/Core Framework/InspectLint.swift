//
//  InspectLint.swift
//  dialog
//
//  Collects every finding about a config before it runs: unknown keys, silent defaults, loader warnings
//  and whole-flow checks. Decodes through `Config.loadConfiguration(fromData:)` so lint and launch agree.
//  Used by `--inspect-lint <config>` and on load (`InspectState`).
//

import Foundation

struct InspectLintFinding: Equatable, Codable, Sendable {
    enum Severity: String, Codable, Sendable { case error, warning }
    let severity: Severity
    /// Where, in the author's terms: `introSteps[choose].optionCards[reinstall_apps].cancels`.
    /// Empty when the message names its own place (the unknown-key walks do).
    let path: String
    let message: String
}

enum InspectLint {

    // MARK: - Entry points

    /// Lint config bytes the way the app would load them.
    @MainActor
    static func lint(data: Data, scriptKeys: Set<String> = [], configPath: String? = nil) -> [InspectLintFinding] {
        // Gradient references are expanded during decode, so unknown ones are caught on the raw JSON.
        let raw = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
        let presets = GradientPresets.unknownReferences(in: raw).map {
            InspectLintFinding(severity: .error, path: $0.path,
                               message: "'\($0.value)' is not a gradient preset; the presets are \(GradientPresets.ids.joined(separator: ", ")).")
        }
        switch Config().loadConfiguration(fromData: data) {
        case .failure(let error):
            return [InspectLintFinding(severity: .error, path: "", message: describe(error))] + presets
        case .success(let result):
            var findings = result.warnings.map { InspectLintFinding(severity: .warning, path: "", message: $0) }
            findings += lint(config: result.config, scriptKeys: scriptKeys, configPath: configPath)
            return findings + presets
        }
    }

    /// The whole-flow checks on a decoded config. Pure, so tests drive it directly.
    static func lint(config: InspectConfig, scriptKeys: Set<String> = [], configPath: String? = nil) -> [InspectLintFinding] {
        let steps = config.introSteps ?? config.steps ?? []
        var out: [InspectLintFinding] = []
        for step in steps {
            out += InspectConfig.silentDefaultAdvisories(for: step)
                .map { InspectLintFinding(severity: .warning, path: "introSteps[\(step.id)]", message: $0) }
        }
        out += duplicateStepIds(steps)
        out += choosers(steps)
        out += followers(steps)
        out += receipts(steps)
        out += showWhenKeys(steps, scriptKeys: scriptKeys)
        out += icons(steps)
        out += sidecarChrome(config, steps: steps, configPath: configPath)
        out += emptyBullets(config, steps: steps)
        return out
    }

    /// `--inspect-lint <config> [--json]`: print every finding, then the exit code — 0 clean,
    /// 1 any error, 2 warnings only.
    @MainActor
    static func runCommandLine(path: String, json: Bool) -> Int32 {
        guard let data = FileManager.default.contents(atPath: path) else {
            print("lint: cannot read \(path)")
            return 1
        }
        let findings = lint(data: data, scriptKeys: scriptKeys(besideConfigAt: path), configPath: path)
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(findings), let text = String(data: data, encoding: .utf8) {
                print(text)
            }
        } else if findings.isEmpty {
            print("lint: \(path) — no findings")
        } else {
            for f in findings {
                let place = f.path.isEmpty ? "" : "\(f.path): "
                print("\(f.severity == .error ? "error" : "warning"): \(place)\(f.message)")
            }
            let errors = findings.filter { $0.severity == .error }.count
            print("lint: \(errors) error(s), \(findings.count - errors) warning(s)")
        }
        return exitCode(for: findings)
    }

    static func exitCode(for findings: [InspectLintFinding]) -> Int32 {
        if findings.contains(where: { $0.severity == .error }) { return 1 }
        return findings.isEmpty ? 0 : 2
    }

    private static func describe(_ error: ConfigurationError) -> String {
        switch error {
        case .invalidFormat(let reason): return reason
        case .invalidJSON(_, let underlying): return "Not valid JSON: \(underlying.localizedDescription)"
        default: return "\(error)"
        }
    }

    // MARK: - Checks

    private static func duplicateStepIds(_ steps: [InspectConfig.IntroStep]) -> [InspectLintFinding] {
        var seen = Set<String>()
        return steps.compactMap { step in
            defer { seen.insert(step.id) }
            return seen.contains(step.id)
                ? InspectLintFinding(severity: .error, path: "introSteps[\(step.id)]",
                                     message: "Step id '\(step.id)' is used twice; goto, receipts and step_list cannot tell them apart.")
                : nil
        }
    }

    /// A multi-select chooser's cards: unique ids, and every `includes` / `cancels` entry naming a
    /// card or a non-empty category.
    private static func choosers(_ steps: [InspectConfig.IntroStep]) -> [InspectLintFinding] {
        var out: [InspectLintFinding] = []
        for step in steps where step.stepType == "options" && step.optionMultiSelect == true {
            let cards = step.optionCards ?? []
            let values = cards.map { $0.value ?? $0.cardId }
            let known = Set(values)
            let categories = Set(cards.compactMap(\.category))
            var seen = Set<String>()
            for value in values {
                if seen.contains(value) {
                    out.append(InspectLintFinding(severity: .error, path: "introSteps[\(step.id)].optionCards[\(value)]",
                                                  message: "Option '\(value)' appears twice; picks and rules cannot tell them apart."))
                }
                seen.insert(value)
            }
            for card in cards {
                let id = card.value ?? card.cardId
                for (field, refs) in [("includes", card.includes ?? []), ("cancels", card.cancels ?? [])] {
                    for ref in refs {
                        let path = "introSteps[\(step.id)].optionCards[\(id)].\(field)"
                        if ref.hasPrefix(OptionPlan.categoryPrefix) {
                            let name = String(ref.dropFirst(OptionPlan.categoryPrefix.count))
                            if !categories.contains(name) {
                                out.append(InspectLintFinding(severity: .error, path: path,
                                    message: "'\(ref)' names no category; the categories are \(categories.sorted().joined(separator: ", "))."))
                            }
                        } else if !known.contains(ref) {
                            out.append(InspectLintFinding(severity: .error, path: path,
                                message: "'\(ref)' is not an option on this step."))
                        }
                    }
                }
            }
        }
        return out
    }

    /// Review and progress steps that follow a chooser must have one to follow.
    private static func followers(_ steps: [InspectConfig.IntroStep]) -> [InspectLintFinding] {
        let chooserKeys = Set(steps.filter { $0.stepType == "options" && $0.optionMultiSelect == true }
            .map { $0.optionKey ?? $0.id })
        var out: [InspectLintFinding] = []
        for step in steps {
            let path = "introSteps[\(step.id)]"
            if step.stepType == "review" {
                guard let key = OptionPlan.followedKey(explicit: step.reviewSelectionKey, in: steps) else {
                    out.append(InspectLintFinding(severity: .error, path: path,
                        message: "This review has no multi-select chooser to follow; add one, or name it with reviewSelectionKey."))
                    continue
                }
                if !chooserKeys.contains(key) {
                    out.append(InspectLintFinding(severity: .error, path: "\(path).reviewSelectionKey",
                        message: "'\(key)' is not the key of a multi-select options step."))
                }
            }
            if step.stepType == "cadence" {
                let derives = (step.cadenceEntries ?? []).isEmpty && step.cadenceRef == nil
                if let key = step.cadenceSelectionKey, !chooserKeys.contains(key) {
                    out.append(InspectLintFinding(severity: .error, path: "\(path).cadenceSelectionKey",
                        message: "'\(key)' is not the key of a multi-select options step."))
                } else if derives, OptionPlan.followedKey(explicit: step.cadenceSelectionKey, in: steps) == nil {
                    out.append(InspectLintFinding(severity: .error, path: path,
                        message: "This progress step has no entries and no chooser to build them from; add a cadence list, or a multi-select options step."))
                }
            }
        }
        return out
    }

    private static func receipts(_ steps: [InspectConfig.IntroStep]) -> [InspectLintFinding] {
        let ids = Set(steps.map(\.id))
        return steps.flatMap { step in
            (step.receipt ?? []).compactMap { row in
                ids.contains(row.stepId) ? nil
                    : InspectLintFinding(severity: .error, path: "introSteps[\(step.id)].receipt[\(row.stepId)]",
                                         message: "The receipt row's Change button points at step '\(row.stepId)', which does not exist.")
            }
        }
    }

    /// Keys recorded by any `select:<key>:` in a sibling `.sh` script, so `showWhen` on them is not
    /// flagged as unreachable.
    static func scriptKeys(besideConfigAt path: String) -> Set<String> {
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        let scripts = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return scripts.filter { $0.pathExtension == "sh" }.reduce(into: Set<String>()) { keys, url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            keys.formUnion(scriptKeys(inScript: text))
        }
    }

    static func scriptKeys(inScript text: String) -> Set<String> {
        let pattern = /select:([A-Za-z0-9_.\-]+):/
        return Set(text.matches(of: pattern).map { String($0.output.1) })
    }

    /// A `showWhen` naming a key nothing in the flow records hides its step for ever.
    private static func showWhenKeys(_ steps: [InspectConfig.IntroStep],
                                     scriptKeys: Set<String>) -> [InspectLintFinding] {
        var recorded = scriptKeys
        // Item outcomes are recorded by every preset but not visible here, so treat them as known.
        recorded.insert(StepOutcome.doneKey(StepOutcome.itemsScope))
        recorded.insert(StepOutcome.failedKey(StepOutcome.itemsScope))
        for step in steps {
            if step.stepType == "options" {
                let key = step.optionKey ?? step.id
                recorded.insert(key)
                if step.optionMultiSelect == true {
                    recorded.insert(OptionPlan.runKey(key)); recorded.insert(OptionPlan.acknowledgedKey(key))
                }
            }
            if let env = step.environments, env.count > 1 { recorded.insert(SplashPick.key(for: step)) }
            if step.stepType == "cadence" {
                recorded.insert(StepOutcome.doneKey(step.id)); recorded.insert(StepOutcome.failedKey(step.id))
            }
            if let key = step.dockSelectionKey { recorded.insert(key) }
            if let key = step.wallpaperSelectionKey { recorded.insert(key) }
            if let key = step.gridSelectionKey { recorded.insert(key) }
            for block in (step.content ?? []) + (step.guidanceContent ?? []) {
                if let id = block.id { recorded.insert(id) }
            }
        }
        var out: [InspectLintFinding] = []
        for step in steps {
            if let rule = step.showWhen, !recorded.contains(rule.key) {
                out.append(InspectLintFinding(severity: .warning, path: "introSteps[\(step.id)].showWhen",
                    message: "Nothing in this flow records '\(rule.key)', so this step will always be skipped."))
            }
            for entry in step.cadenceEntries ?? [] {
                if let rule = entry.showWhen, !recorded.contains(rule.key) {
                    out.append(InspectLintFinding(severity: .warning, path: "introSteps[\(step.id)].cadence[\(entry.id)].showWhen",
                        message: "Nothing in this flow records '\(rule.key)', so this entry never runs."))
                }
            }
        }
        return out
    }

    /// A `bullets` block draws its `items` only (3.1.1 did the same); with `content` and no items it
    /// draws nothing.
    static func emptyBullets(_ config: InspectConfig, steps: [InspectConfig.IntroStep]) -> [InspectLintFinding] {
        var places: [(String, [InspectConfig.GuidanceContent])] = steps.map {
            ("introSteps[\($0.id)]", ($0.content ?? []) + ($0.guidanceContent ?? []))
        }
        places += config.items.map { ("items[\($0.id)]", $0.guidanceContent ?? []) }
        return places.flatMap { place, blocks in
            blocks.enumerated().compactMap { index, block in
                guard block.type == "bullets", block.items?.isEmpty ?? true else { return nil }
                return InspectLintFinding(severity: .warning, path: "\(place).content[\(index)]",
                    message: "A bullets block draws its 'items' list; it has none, so it shows nothing"
                        + (block.content == nil ? "." : " (its 'content' is not drawn)."))
            }
        }
    }

    /// The step chrome a sidecar must carry for a translated flow, else it stays in the config's own
    /// language: `<stepId>.continueButtonText`, `<stepId>.backButtonText` on every step after the
    /// first, and on Preset 5 the card counter `_ui.stepCounterFormat`. swiftDialog's own
    /// Localizable.strings has none of these and follows the system locale, not the sidecar.
    /// One finding per language file. Sidecars that cannot be read are left to the loader's log.
    static func sidecarChrome(_ config: InspectConfig, steps: [InspectConfig.IntroStep],
                              configPath: String?) -> [InspectLintFinding] {
        guard let localization = config.localization, !steps.isEmpty else { return [] }
        let base = LocalizationService.sidecarBase(iconBasePath: config.iconBasePath, configPath: configPath)
        // The built-in chrome is English, so an English sidecar needs no chrome keys.
        let english = LocalizationService.languageKey(forCode: "en", in: localization.languages)
        var out: [InspectLintFinding] = []
        for (language, file) in localization.languages.sorted(by: { $0.key < $1.key }) where language != english {
            let path = file.hasPrefix("/") ? file : (base as NSString).appendingPathComponent(file)
            guard let data = FileManager.default.contents(atPath: path),
                  let strings = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            var wanted = steps.map { "\($0.id).continueButtonText" }
            wanted += steps.dropFirst().map { "\($0.id).backButtonText" }
            if InspectPresetName.engine(config.preset) == 5, steps.count > 1 { wanted.append("_ui.stepCounterFormat") }
            let missing = wanted.filter { strings[$0] == nil }
            guard !missing.isEmpty else { continue }
            out.append(InspectLintFinding(severity: .warning, path: "localization.languages[\(language)]",
                message: "\(file) has no \(missing.joined(separator: ", ")); those buttons and the step counter stay untranslated in \(language)."))
        }
        return out
    }

    /// A missing icon file or app is only a warning: the row falls back to its symbol, and the target Mac may have it.
    private static func icons(_ steps: [InspectConfig.IntroStep]) -> [InspectLintFinding] {
        var out: [InspectLintFinding] = []
        for step in steps {
            for card in step.optionCards ?? [] {
                guard let path = card.iconPath, path.hasPrefix("/") || path.hasPrefix("~") else { continue }
                if !FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath) {
                    out.append(InspectLintFinding(severity: .warning,
                        path: "introSteps[\(step.id)].optionCards[\(card.value ?? card.cardId)].iconPath",
                        message: "'\(path)' is not on this Mac; the row shows its symbol instead."))
                }
            }
        }
        return out
    }
}
