//
//  Preset5+ContentBlocks.swift
//  dialog
//
//  Preset 5 extension: `introContentBlock`, the per-block dispatcher for step guidance blocks.
//  Most types render through GuidanceContentView with plist and IPC state merged in; the phase
//  tracker and form fields are handled here.
//

import SwiftUI

extension Preset5View {

    /// Renders a guidance content block. `blockIndex` keys dynamic updates.
    @ViewBuilder
    func introContentBlock(_ block: InspectConfig.GuidanceContent, blockIndex: Int = 0) -> some View {
        // Plist monitor state first, then IPC state (update_guidance, batch updates).
        let plistState = introStepMonitor.stateForBlock(blockIndex)
        let plistBlock = applyDynamicState(to: block, dynamicState: plistState)
        let effectiveBlock = applyIPCState(to: plistBlock, blockIndex: blockIndex, stepId: currentStep?.id ?? "")

        switch effectiveBlock.type {
        // MARK: - Delegated content types
        case "text", "prose", "bullets", "info", "warning", "success", "arrow",
             "highlight", "label-value", "explainer", "image", "video", "button",
             // These arrive with plist and IPC state merged into `effectiveBlock`.
             "feature-table", "comparison-table", "compliance-card", "compliance-header",
             "progress-bar", "image-carousel", "compliance-details-button",
             "status-badge":
            // Media uses full width; other blocks take the stance's measure.
            let wideBlock = (effectiveBlock.type == "video" || effectiveBlock.type == "image")
            let s = stance
            centeredContentContainer(maxWidth: wideBlock ? .infinity : s.maxWidth(metrics),
                                     alignment: s.frameAlignment) {
                GuidanceContentView(
                    contentBlocks: [effectiveBlock],
                    scaleFactor: 1.0,
                    iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                    inspectState: inspectState,
                    itemId: "intro-block-\(blockIndex)",
                    accentColor: branding.primaryColor,
                    contentAlignment: s.align
                )
            }

        case "phase-tracker":
            introPhaseTrackerView(block: effectiveBlock, blockIndex: blockIndex, dynamicState: plistState)

        // MARK: Form Elements
        // Form values are keyed by step id, which `legacyFormValues(for:)` and every export read; a
        // synthetic block id would write to a store nothing reads. `formWire` sets Preset 5's line format
        // and preferences write-through for all six types.
        case "checkbox", "toggle", "dropdown", "radio", "textfield", "slider":
            // Forms keep the reading column (`metrics.contentMaxW`) rather than full bleed, and follow the
            // stance's alignment so fields line up with their heading.
            centeredContentContainer(maxWidth: metrics.contentMaxW, alignment: stance.frameAlignment) {
                GuidanceContentView(
                    contentBlocks: [effectiveBlock],
                    scaleFactor: 1.0,
                    iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                    inspectState: inspectState,
                    itemId: formStoreStepId,
                    accentColor: branding.primaryColor,
                    contentAlignment: .leading,
                    formWire: FormWire(
                        dialect: .step3Part,
                        onValueCommit: { fieldId, value in
                            preferencesService?.setValue(value, forKey: fieldId)
                        }
                    )
                )
                // Leading-align within the column; the container applies one alignment to both of its frames.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                // Fallback seeding; the result file's seeded form values depend on it.
                seedFormDefaultIfNeeded(block: effectiveBlock)
            }

        // Compliance blocks (cards, header, summary, findings, details button) need no arm here:
        // GuidanceContentView reads the service through \.complianceAggregator.

        default:
            // Everything else goes to GuidanceContentView. Checklist results come from Preset5View's
            // `checklistLineSatisfied`, keyed by step id (filled by `evaluateChecklistLines`).
            GuidanceContentView(
                contentBlocks: [block],
                scaleFactor: 1.0,
                iconBasePath: dynamicState.iconBasePathOverride ?? inspectState.uiConfiguration.iconBasePath,
                inspectState: inspectState,
                itemId: "intro-block-\(blockIndex)",
                accentColor: branding.primaryColor,
                contentAlignment: stance.align,
                checklistLineSatisfied: block.type == "checklist" ? checklistLineSatisfied[currentStep?.id ?? ""] : nil
            )
        }
    }

    /// The shared `PhaseTrackerView` with the brand accent and the block's caption.
    /// Phase priority: dynamicState, then the block (`set:phase-tracker` writes it), then config.
    @ViewBuilder
    func introPhaseTrackerView(block: InspectConfig.GuidanceContent, blockIndex: Int = 0, dynamicState: DynamicContentState? = nil) -> some View {
        let phases = block.phases.map(Array.init) ?? []
        let effectivePhase = dynamicState?.currentPhase ?? (block.currentPhase ?? 1)

        // Full width: a timeline's widths carry meaning, and Preset 6 draws it full width too.
        centeredContentContainer(maxWidth: .infinity, alignment: stance.frameAlignment) {
            if !phases.isEmpty {
                PhaseTrackerView(
                    currentPhase: effectivePhase,
                    phases: phases,
                    // Honour the block's own style so `style: "progress"` is reachable.
                    style: block.style ?? "stepper",
                    scaleFactor: 1.0,
                    activeColor: branding.primaryColor,
                    caption: block.label,
                    progress: block.progress
                )
            }
        }
    }
}
