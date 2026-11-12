//
//  InspectConfig+StepCanonicalization.swift
//  dialog
//
//  Step canonicalization: shorthand step forms are rewritten into their explicit form at decode.
//

import Foundation
import SwiftUI

// MARK: - Step canonicalization

extension InspectConfig {

    /// Renderers selected by field presence, in dispatch order. The order must match
    /// `introStepView` in `Preset5+CoreSteps.swift` and the schema's enum.
    static let stepRendererPriority: [(renderer: String, matches: @Sendable (IntroStep) -> Bool)] = [
        ("installation", { !($0.installationMode ?? "").isEmpty }),
        ("wallpaper", { !($0.wallpaperCategories ?? []).isEmpty }),
        ("options", { !($0.optionCards ?? []).isEmpty }),
        ("dock", { !($0.dockFlavors ?? []).isEmpty || !($0.dockItems ?? []).isEmpty })
    ]

    /// `stepType` values that name a phase rather than a renderer.
    static let stepPhaseValues: Set<String> = ["intro", "outro", "main"]

    /// Whether a check's state word is a pass; nil when the word has no two-valued reading.
    /// Uses the `ExternalFactStatus` vocabulary, not `StepStatus`.
    static func verdictIsPass(_ state: String) -> Bool? {
        ExternalFactStatus.classify(state.trimmingCharacters(in: .whitespacesAndNewlines)).verdict
    }

    /// Folds single-datum `comparison-table` blocks onto `checks[]`: consecutive blocks sharing a
    /// `category` become one table labelled by it; a block without one folds alone. Blocks that
    /// already carry `checks[]` pass through, which keeps this idempotent.
    static func foldComparisonChecks(_ blocks: inout [GuidanceContent]?,
                                     id: String,
                                     advisories: inout [String]) {
        guard let input = blocks, !input.isEmpty else { return }

        // A block with neither `checks` nor a scalar is half-authored and stays for the debug hint.
        func isSingular(_ b: GuidanceContent) -> Bool {
            b.type == "comparison-table" && b.checks == nil
                && (b.expected != nil || b.actual != nil)
        }

        var out: [GuidanceContent] = []
        var i = 0
        var foldedRuns = 0

        while i < input.count {
            guard isSingular(input[i]) else { out.append(input[i]); i += 1; continue }

            // A nil category cannot group adjacent lone checks.
            var run = [input[i]]
            var j = i + 1
            if let category = input[i].category {
                while j < input.count, isSingular(input[j]), input[j].category == category {
                    run.append(input[j])
                    j += 1
                }
            }

            var merged = run[0]
            merged.checks = run.map { block in
                GuidanceContent.ComparisonCheck(
                    check: block.label ?? block.content ?? "",
                    required: block.expected ?? "-",
                    found: block.actual ?? "-",
                    // From `state`, never `required == found`: passing values need not be string-equal.
                    pass: block.state.flatMap { verdictIsPass($0) },
                    expanded: nil,
                    note: nil,
                    actionLabel: nil,
                    actionURL: nil
                )
            }
            merged.label = run[0].category ?? run[0].label
            // Consumed, so one spelling exists downstream.
            merged.category = nil
            merged.expected = nil
            merged.actual = nil
            merged.state = nil

            out.append(merged)
            foldedRuns += 1
            advisories.append("step '\(id)': \(run.count) single-datum 'comparison-table' "
                              + "block(s) folded into one 'checks' table"
                              + (merged.label.map { " (\($0))" } ?? ""))
            i = j
        }

        if foldedRuns > 0 { blocks = out }
    }

    /// Block types whose caption may be spelled `label` or `content`. `content` is canonical
    /// because the interaction log and action handler read it. `identity` handles both itself.
    static let labelAliasTypes: Set<String> = [
        "button",
        "dropdown", "radio", "checkbox", "toggle", "slider",
        "textfield", "segmented", "search", "multi-select"
    ]

    /// Fills an absent `content` from `label` for `labelAliasTypes`; an authored `content` wins.
    static func foldLabelAliases(_ blocks: inout [GuidanceContent]?,
                                 id: String,
                                 advisories: inout [String]) {
        guard var input = blocks, !input.isEmpty else { return }

        var folded = 0
        for i in input.indices where labelAliasTypes.contains(input[i].type) {
            guard input[i].content == nil, let label = input[i].label else { continue }
            input[i].content = label
            folded += 1
            advisories.append("step '\(id)': \(input[i].type) 'label' is an alias of 'content' — folded (\(label))")
        }

        if folded > 0 { blocks = input }
    }

    /// Block folds shared by every block-decoding site: step `content[]`, item `guidanceContent[]`
    /// and the root `guidanceContent[]`. Preset 6 decodes `items[]` both ways, so both must agree.
    /// `inferButtonActions` is step-level only. Sidebar, card-screen, bookend and overlay block
    /// arrays are decoded without this.
    static func canonicalizeBlocks(_ blocks: inout [GuidanceContent]?,
                                   id: String,
                                   advisories: inout [String]) {
        foldComparisonChecks(&blocks, id: id, advisories: &advisories)
        foldLabelAliases(&blocks, id: id, advisories: &advisories)
        foldBlockDockPayloads(&blocks, id: id, advisories: &advisories)
        foldBlockPickerPayloads(&blocks, id: id, advisories: &advisories)
    }

    /// Folds a block's grouped `option` and `wallpaper` containers onto their flat keys, as the
    /// step level does. Block-only presentation keys (`options`, `optionDetails`, `optionIcons`,
    /// `wallpaperColumns`, `wallpaperImageFit`) stay flat.
    static func foldBlockPickerPayloads(_ blocks: inout [GuidanceContent]?,
                                        id: String,
                                        advisories: inout [String]) {
        guard var input = blocks, !input.isEmpty else { return }

        var folded = 0
        for i in input.indices {
            guard input[i].option != nil || input[i].wallpaper != nil else { continue }

            func fold<T>(_ flat: inout T?, _ nested: T?, _ groupedKey: String, _ flatKey: String) {
                guard let nested else { return }
                if flat != nil {
                    advisories.append("'\(id)' block[\(i)]: both '\(groupedKey)' and '\(flatKey)' "
                                      + "authored — the grouped value wins")
                }
                flat = nested
            }

            if let payload = input[i].option {
                fold(&input[i].optionCards, payload.cards, "option.cards", "optionCards")
                fold(&input[i].optionConfirmButton, payload.confirmButton, "option.confirmButton", "optionConfirmButton")
                // `option.key`, not `selectionKey`: the step-level spelling is mirrored.
                fold(&input[i].optionKey, payload.key, "option.key", "optionKey")
                fold(&input[i].optionLayout, payload.layout, "option.layout", "optionLayout")
                fold(&input[i].optionMultiSelect, payload.multiSelect, "option.multiSelect", "optionMultiSelect")
                fold(&input[i].optionPreferenceKey, payload.preferenceKey, "option.preferenceKey", "optionPreferenceKey")
                input[i].option = nil
            }
            if let payload = input[i].wallpaper {
                fold(&input[i].wallpaperCategories, payload.categories, "wallpaper.categories", "wallpaperCategories")
                fold(&input[i].wallpaperConfirmButton, payload.confirmButton, "wallpaper.confirmButton", "wallpaperConfirmButton")
                fold(&input[i].wallpaperLayout, payload.layout, "wallpaper.layout", "wallpaperLayout")
                fold(&input[i].wallpaperMultiSelect, payload.multiSelect, "wallpaper.multiSelect", "wallpaperMultiSelect")
                fold(&input[i].wallpaperPreferenceKey, payload.preferenceKey, "wallpaper.preferenceKey", "wallpaperPreferenceKey")
                fold(&input[i].wallpaperSelectionKey, payload.selectionKey, "wallpaper.selectionKey", "wallpaperSelectionKey")
                fold(&input[i].wallpaperShowPath, payload.showPath, "wallpaper.showPath", "wallpaperShowPath")
                fold(&input[i].wallpaperThumbnailHeight, payload.thumbnailHeight, "wallpaper.thumbnailHeight", "wallpaperThumbnailHeight")
                input[i].wallpaper = nil
            }
            folded += 1
        }

        if folded > 0 { blocks = input }
    }

    /// Folds a block's grouped `dock` container onto the flat `dock*` keys, as the step level does.
    static func foldBlockDockPayloads(_ blocks: inout [GuidanceContent]?,
                                      id: String,
                                      advisories: inout [String]) {
        guard var input = blocks, !input.isEmpty else { return }

        var folded = 0
        for i in input.indices {
            guard let payload = input[i].dock else { continue }

            func fold<T>(_ flat: inout T?, _ nested: T?, _ groupedKey: String, _ flatKey: String) {
                guard let nested else { return }
                if flat != nil {
                    advisories.append("'\(id)' block[\(i)]: both '\(groupedKey)' and '\(flatKey)' "
                                      + "authored — the grouped value wins")
                }
                flat = nested
            }

            fold(&input[i].dockApplyMode, payload.applyMode, "dock.applyMode", "dockApplyMode")
            fold(&input[i].dockConfirmButton, payload.confirmButton, "dock.confirmButton", "dockConfirmButton")
            fold(&input[i].dockDecline, payload.decline, "dock.decline", "dockDecline")
            fold(&input[i].dockFlavors, payload.flavors, "dock.flavors", "dockFlavors")
            fold(&input[i].dockItems, payload.items, "dock.items", "dockItems")
            fold(&input[i].dockLayout, payload.layout, "dock.layout", "dockLayout")
            fold(&input[i].dockMode, payload.mode, "dock.mode", "dockMode")
            fold(&input[i].dockPreferenceKey, payload.preferenceKey, "dock.preferenceKey", "dockPreferenceKey")
            fold(&input[i].dockSelectionKey, payload.selectionKey, "dock.selectionKey", "dockSelectionKey")
            fold(&input[i].dockShowUnavailable, payload.showUnavailable, "dock.showUnavailable", "dockShowUnavailable")
            // Consumed, so a second pass is a no-op.
            input[i].dock = nil
            folded += 1
        }

        if folded > 0 { blocks = input }
    }

    /// Folds `summaryScreen`'s grouped `dock` container onto its flat keys; called from the root
    /// decoder, since the screen is not a block.
    static func canonicalizeSummaryScreen(_ screen: PresetSummaryScreen,
                                          advisories: inout [String]) -> PresetSummaryScreen {
        guard let payload = screen.dock else { return screen }
        var out = screen

        func fold<T>(_ flat: inout T?, _ nested: T?, _ groupedKey: String, _ flatKey: String) {
            guard let nested else { return }
            if flat != nil {
                advisories.append("summaryScreen: both '\(groupedKey)' and '\(flatKey)' authored "
                                  + "— the grouped value wins")
            }
            flat = nested
        }

        fold(&out.dockApplyMode, payload.applyMode, "dock.applyMode", "dockApplyMode")
        fold(&out.dockConfirmButton, payload.confirmButton, "dock.confirmButton", "dockConfirmButton")
        fold(&out.dockDecline, payload.decline, "dock.decline", "dockDecline")
        fold(&out.dockFlavors, payload.flavors, "dock.flavors", "dockFlavors")
        fold(&out.dockItems, payload.items, "dock.items", "dockItems")
        fold(&out.dockLayout, payload.layout, "dock.layout", "dockLayout")
        fold(&out.dockMode, payload.mode, "dock.mode", "dockMode")
        fold(&out.dockPreferenceKey, payload.preferenceKey, "dock.preferenceKey", "dockPreferenceKey")
        fold(&out.dockSelectionKey, payload.selectionKey, "dock.selectionKey", "dockSelectionKey")
        fold(&out.dockShowUnavailable, payload.showUnavailable, "dock.showUnavailable", "dockShowUnavailable")
        out.dock = nil
        return out
    }

    /// A button with a payload but no `action` gets the action its payload implies, precedence
    /// url > shell > requestId. A button with no payload is left for the handler to report.
    static func inferButtonActions(_ blocks: inout [GuidanceContent]?,
                                   id: String,
                                   advisories: inout [String]) {
        guard var input = blocks, !input.isEmpty else { return }

        var inferred = 0
        for i in input.indices where input[i].type == "button" && input[i].action == nil {
            let payloads: [(String, Bool)] = [
                ("url", input[i].url != nil),
                ("shell", input[i].shell != nil),
                ("request", input[i].requestId != nil)
            ]
            let present = payloads.filter(\.1).map(\.0)
            guard let action = present.first else { continue }

            input[i].action = action
            inferred += 1
            advisories.append("step '\(id)': button '\(input[i].content ?? "?")' has no 'action' — "
                              + "inferred '\(action)' from its payload"
                              + (present.count > 1 ? " (also carries \(present.dropFirst().joined(separator: ", ")))" : ""))
        }

        if inferred > 0 { blocks = input }
    }

    /// The one desugaring pass: pure and idempotent, so the same bytes canonicalize the same way
    /// at decode, on resume and over IPC (`step_add`). It never adds, removes or reorders steps,
    /// so index-keyed consumers stay valid.
    static func canonicalizeStep(_ step: IntroStep, advisories: inout [String]) -> IntroStep {
        var out = step

        // Grouped payloads fold first: the renderer chain below tests the flat keys.
        foldNestedPayloads(&out, id: step.id, advisories: &advisories)

        // Aliases fill an absent canonical field and are cleared either way; a surviving duplicate
        // would escape the secure-field exclusion set built from `content`.
        if out.title == nil, let aliased = out.guidanceTitle {
            out.title = aliased
            advisories.append("step '\(step.id)': 'guidanceTitle' is an alias of 'title' — folded")
        }
        if out.content == nil, let aliased = out.guidanceContent {
            out.content = aliased
            advisories.append("step '\(step.id)': 'guidanceContent' is an alias of 'content' — folded")
        }
        // `guideText` becomes a trailing text block, so an authored `content` keeps its opening.
        if let guideCopy = out.guideText, !guideCopy.isEmpty {
            // `GuidanceContent` has no memberwise init; decoding JSON keeps the block as valid as an authored one.
            if let data = try? JSONSerialization.data(withJSONObject: ["type": "text", "content": guideCopy]),
               let block = try? JSONDecoder().decode(GuidanceContent.self, from: data) {
                var blocks = out.content ?? []
                blocks.append(block)
                out.content = blocks
                advisories.append("step '\(step.id)': 'guideText' folded into content as a text block")
            } else {
                advisories.append("step '\(step.id)': 'guideText' could not be folded into a text block")
            }
        }
        out.guideText = nil
        out.guidanceTitle = nil
        out.guidanceContent = nil
        // After the alias fold so both container spellings reach it.
        canonicalizeBlocks(&out.content, id: step.id, advisories: &advisories)
        // After the caption fold so the advisory can name the button. Step-level only.
        inferButtonActions(&out.content, id: step.id, advisories: &advisories)
        // Preset 6 item vocabulary. `displayName` is not folded: it is the rail label, not the title.
        if out.heroImage == nil, let aliased = out.icon {
            out.heroImage = aliased
            advisories.append("step '\(step.id)': 'icon' is an alias of 'heroImage' — folded")
        }
        if out.stepOverlay == nil, let aliased = out.itemOverlay {
            out.stepOverlay = aliased
            advisories.append("step '\(step.id)': 'itemOverlay' is an alias of 'stepOverlay' — folded")
        }
        out.icon = nil
        out.itemOverlay = nil

        // Rescue an authored phase before the renderer overwrites `stepType`.
        if out.phase == nil, let authored = out.stepType, stepPhaseValues.contains(authored) {
            out.phase = authored
        }

        // Field presence wins over an authored renderer, because that is what the dispatcher obeys.
        if let matched = stepRendererPriority.first(where: { $0.matches(out) })?.renderer {
            if let authored = out.stepType,
               !stepPhaseValues.contains(authored),
               authored != matched {
                advisories.append(
                    "step '\(step.id)': stepType '\(authored)' is overridden by the '\(matched)' "
                    + "renderer its fields select — the authored value was already inert")
            }
            out.stepType = matched
        }

        // "standard", not "intro": an authored `stepType: "intro"` still means the phase.
        if out.stepType == nil {
            out.stepType = "standard"
        }

        return out
    }

    /// Advisories for absent keys whose default decides an outcome (a verdict, a Dock rewrite),
    /// emitted only when the step uses the feature the key governs.
    static func silentDefaultAdvisories(for step: IntroStep) -> [String] {
        var out: [String] = []
        let id = step.id

        // An authored step cannot carry the ceremony vocabulary; only the root keys render it in full.
        if let layout = step.layout, layout != "centered",
           stepRenderableBookendLayouts.contains(layout),
           !reservedBookendIds.contains(id) {
            out.append("step '\(id)': layout '\(layout)' is a bookend ceremony — author it "
                       + "as introScreen/summaryScreen (the projection renders it in full); "
                       + "an authored step shows the plain column")
        }

        if step.expectedValue != nil,
           let note = EvaluationOperator.derivationNote(evaluation: step.evaluation,
                                                        expectedValue: step.expectedValue) {
            out.append("step '\(id)': \(note)")
        }

        let isProcessing = step.processingDuration != nil || step.stepType == "processing"
        if isProcessing && step.autoResult == nil {
            out.append("step '\(id)': no 'autoResult' authored — a script that never reports "
                       + "will be recorded as 'success'")
        }
        if isProcessing && step.processingMode == nil {
            out.append("step '\(id)': no 'processingMode' authored — using 'simple', which "
                       + "auto-completes rather than waiting for a trigger")
        }
        let triggerCount = (step.plistMonitors ?? []).filter { $0.completionTrigger != nil }.count
        if triggerCount > 1 && step.completionMode == nil {
            out.append("step '\(id)': \(triggerCount) completion triggers and no 'completionMode' "
                       + "— using 'any', so the step completes on the FIRST one to fire")
        }
        if (step.dockItems != nil || step.dockFlavors != nil) && step.dockApplyMode == nil {
            out.append("step '\(id)': no 'dockApplyMode' authored — using 'additive', which "
                       + "appends to the existing Dock rather than replacing it")
        }
        if step.gridItems != nil && step.gridSelectionMode == nil {
            out.append("step '\(id)': no 'gridSelectionMode' authored — using 'single'")
        }

        return out
    }

    /// Folds every grouped payload onto the flat keys the renderers read. Grouped wins when both
    /// are present, always with an advisory.
    private static func foldNestedPayloads(_ out: inout IntroStep, id: String,
                                           advisories: inout [String]) {
        func fold<T>(_ flat: inout T?, _ nested: T?, _ groupedKey: String, _ flatKey: String) {
            guard let nested else { return }
            if flat != nil {
                advisories.append("step '\(id)': both '\(groupedKey)' and '\(flatKey)' authored "
                                  + "— the grouped value wins")
            }
            flat = nested
        }


        if let p = out.wallpaper {
            fold(&out.wallpaperCategories, p.categories, "wallpaper.categories", "wallpaperCategories")
            fold(&out.wallpaperConfirmButton, p.confirmButton, "wallpaper.confirmButton", "wallpaperConfirmButton")
            fold(&out.wallpaperLayout, p.layout, "wallpaper.layout", "wallpaperLayout")
            fold(&out.wallpaperMultiSelect, p.multiSelect, "wallpaper.multiSelect", "wallpaperMultiSelect")
            fold(&out.wallpaperPreferenceKey, p.preferenceKey, "wallpaper.preferenceKey", "wallpaperPreferenceKey")
            fold(&out.wallpaperSelectionKey, p.selectionKey, "wallpaper.selectionKey", "wallpaperSelectionKey")
            fold(&out.wallpaperShowPath, p.showPath, "wallpaper.showPath", "wallpaperShowPath")
            fold(&out.wallpaperThumbnailHeight, p.thumbnailHeight, "wallpaper.thumbnailHeight", "wallpaperThumbnailHeight")
        }
        if let p = out.option {
            fold(&out.optionCards, p.cards, "option.cards", "optionCards")
            fold(&out.optionConfirmButton, p.confirmButton, "option.confirmButton", "optionConfirmButton")
            fold(&out.optionKey, p.key, "option.key", "optionKey")
            fold(&out.optionLayout, p.layout, "option.layout", "optionLayout")
            fold(&out.optionMultiSelect, p.multiSelect, "option.multiSelect", "optionMultiSelect")
            fold(&out.optionPreferenceKey, p.preferenceKey, "option.preferenceKey", "optionPreferenceKey")
        }
        if let p = out.dock {
            fold(&out.dockApplyMode, p.applyMode, "dock.applyMode", "dockApplyMode")
            fold(&out.dockConfirmButton, p.confirmButton, "dock.confirmButton", "dockConfirmButton")
            fold(&out.dockDecline, p.decline, "dock.decline", "dockDecline")
            fold(&out.dockFlavors, p.flavors, "dock.flavors", "dockFlavors")
            fold(&out.dockItems, p.items, "dock.items", "dockItems")
            fold(&out.dockLayout, p.layout, "dock.layout", "dockLayout")
            fold(&out.dockMode, p.mode, "dock.mode", "dockMode")
            fold(&out.dockPreferenceKey, p.preferenceKey, "dock.preferenceKey", "dockPreferenceKey")
            fold(&out.dockSelectionKey, p.selectionKey, "dock.selectionKey", "dockSelectionKey")
            fold(&out.dockShowUnavailable, p.showUnavailable, "dock.showUnavailable", "dockShowUnavailable")
        }
        if let p = out.media {
            fold(&out.mediaAutoplay, p.autoplay, "media.autoplay", "mediaAutoplay")
            fold(&out.mediaFit, p.fit, "media.fit", "mediaFit")
            fold(&out.mediaHeight, p.height, "media.height", "mediaHeight")
            fold(&out.mediaItems, p.items, "media.items", "mediaItems")
            fold(&out.mediaLayout, p.layout, "media.layout", "mediaLayout")
            fold(&out.mediaStage, p.stage, "media.stage", "mediaStage")
            fold(&out.mediaRatio, p.ratio, "media.ratio", "mediaRatio")
            fold(&out.mediaShowArrows, p.showArrows, "media.showArrows", "mediaShowArrows")
            fold(&out.mediaShowDots, p.showDots, "media.showDots", "mediaShowDots")
            fold(&out.mediaSide, p.side, "media.side", "mediaSide")
        }
        if let p = out.bento {
            fold(&out.bentoCells, p.cells, "bento.cells", "bentoCells")
            fold(&out.bentoColumns, p.columns, "bento.columns", "bentoColumns")
            fold(&out.bentoGap, p.gap, "bento.gap", "bentoGap")
            fold(&out.bentoLayout, p.layout, "bento.layout", "bentoLayout")
            fold(&out.bentoRowHeight, p.rowHeight, "bento.rowHeight", "bentoRowHeight")
            fold(&out.bentoShowSlots, p.showSlots, "bento.showSlots", "bentoShowSlots")
            fold(&out.bentoSidebarContent, p.sidebarContent, "bento.sidebarContent", "bentoSidebarContent")
            fold(&out.bentoSidebarRatio, p.sidebarRatio, "bento.sidebarRatio", "bentoSidebarRatio")
            fold(&out.bentoTintColor, p.tintColor, "bento.tintColor", "bentoTintColor")
        }
        if let p = out.showcase {
            fold(&out.showcaseGradientColors, p.gradientColors, "showcase.gradientColors", "showcaseGradientColors")
            fold(&out.showcaseImageHeight, p.imageHeight, "showcase.imageHeight", "showcaseImageHeight")
            fold(&out.showcaseTextColor, p.textColor, "showcase.textColor", "showcaseTextColor")
        }
        // `software.agentLabel` is canonical and folds last, so it wins; do not swap these two blocks.
        let agentLabelCameFromAssistant = out.assistant?.agentLabel != nil
        if let p = out.assistant {
            fold(&out.agentLabel, p.agentLabel, "assistant.agentLabel", "agentLabel")
            fold(&out.assistantImageHeight, p.imageHeight, "assistant.imageHeight", "assistantImageHeight")
        }
        if let p = out.software {
            fold(&out.bundles, p.bundles, "software.bundles", "bundles")
            fold(&out.softwareNote, p.note, "software.note", "softwareNote")
            // `fold` would misreport this as a grouped-versus-flat conflict.
            if let label = p.agentLabel, agentLabelCameFromAssistant {
                advisories.append("step '\(id)': 'agentLabel' authored in both 'software' and the "
                                  + "legacy 'assistant' container — 'software.agentLabel' wins")
                out.agentLabel = label
            } else {
                fold(&out.agentLabel, p.agentLabel, "software.agentLabel", "agentLabel")
            }
        }

        fold(&out.portalConfig, out.portal, "portal", "portalConfig")

        // Consumed: one spelling per fact keeps `canonicalStepJSON` a faithful identity and this idempotent.
        out.wallpaper = nil; out.option = nil; out.dock = nil; out.media = nil; out.bento = nil
        out.showcase = nil; out.assistant = nil; out.software = nil
        out.portal = nil

        // Cadence shares one key (see CadencePayload); only its siblings fold.
        if let c = out.cadence {
            fold(&out.cadenceStyle, c.style, "cadence.style", "cadenceStyle")
            fold(&out.cadenceInterval, c.interval, "cadence.interval", "cadenceInterval")
            fold(&out.cadenceMinDwell, c.minDwell, "cadence.minDwell", "cadenceMinDwell")
            fold(&out.cadenceRef, c.ref, "cadence.ref", "cadenceRef")
        }
    }

    /// Preset 6 `items[]` in `guiIndex` order, the documented display order 3.1.1 sorted by.
    /// `rows` is the same array decoded as ItemConfig, which carries `guiIndex` (0 when absent).
    /// Stable, so equal indexes, including all-zero ones, keep the authored order.
    static func orderedByGuiIndex(_ steps: [IntroStep], rows: [ItemConfig]) -> [IntroStep] {
        guard steps.count == rows.count else { return steps }
        return zip(steps, rows).enumerated()
            .sorted { ($0.element.1.guiIndex, $0.offset) < ($1.element.1.guiIndex, $1.offset) }
            .map { $0.element.0 }
    }

    /// Canonicalizes a whole list and logs the advisories once. Count-preserving.
    static func canonicalizeSteps(_ steps: [IntroStep]?) -> [IntroStep]? {
        guard let steps else { return nil }
        var advisories: [String] = []
        let out = steps.map { canonicalizeStep($0, advisories: &advisories) }
        // Observations, not rewrites: inside canonicalizeStep they would break its idempotence.
        for step in out {
            advisories.append(contentsOf: silentDefaultAdvisories(for: step))
        }
        for line in advisories {
            writeLog("InspectConfig: \(line)", logLevel: .info)
        }
        return out
    }
}
