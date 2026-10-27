//
//  Preset5+CardExport.swift
//  dialog
//
//  The substeps mini-wizard and the export/save-file card.
//

import SwiftUI

extension Preset5View {
    /// The substeps mini-wizard: `substeps[]` paged by the action-bar pager, sharing the page
    /// store with `screens[]`. The flow advances only past the last page.
    @ViewBuilder
    func cardSubstepsWizardView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let subs = step.substeps ?? []
        let idx = subs.isEmpty ? 0
            : min(max(0, inspectState.cardSubStepIndex[step.id] ?? 0), subs.count - 1)
        let isLast = idx >= subs.count - 1
        let flowBack = canGoBack(fromStepIndex: stepIndex) && (step.showBackButton ?? true)
        let canBack = flowBack || idx > 0
        CardStepShell(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            hero: cardHero(step),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            accent: branding.primaryColor,
            // Back walks the wizard before it leaves the step; the primary says "Next" until the last page.
            footer: cardFooter(
                for: step, index: stepIndex,
                showBack: canBack,
                continueText: isLast
                    ? (localized("continueButtonText", forStep: step,
                                 fallback: step.continueButtonText) ?? ChromeCopy.continue)
                    : "Next",
                subStepper: subs.count > 1 ? CardSubStepperModel(
                    current: idx,
                    total: subs.count,
                    onPrev: idx > 0
                        ? { inspectState.cardSubStepIndex[step.id] = idx - 1 } : nil,
                    onNext: !isLast
                        ? { inspectState.cardSubStepIndex[step.id] = idx + 1 } : nil
                ) : nil,
                onBack: {
                    if idx > 0 { inspectState.cardSubStepIndex[step.id] = idx - 1 } else { goToPreviousStep() }
                }
            ) {
                if isLast {
                    inspectState.cardSubStepIndex[step.id] = 0
                    goToNextStep()
                } else {
                    inspectState.cardSubStepIndex[step.id] = idx + 1
                }
            }
        ) {
            ScrollView(.vertical) {
                if subs.indices.contains(idx) {
                    substepContent(subs[idx])
                        // Leading alignment keeps the body on the header's edge.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("card-substep-\(step.id)-\(idx)")   // fresh media/view per page
                        .transition(.opacity)
                }
            }
        }
        .sourceTag()
    }

    /// The export step. Sizes and editors are measured at render; nothing is written until a
    /// button is pressed. Primary writes, opens the editor and finishes; secondary writes and reveals.
    @ViewBuilder
    func cardExportStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let payload = step.export
        let items = payload?.items ?? []
        let measured = items.map(CardExportEngine.measure)
        let editors = (payload?.editors ?? []).map(CardExportEngine.detect)
        let installed = editors.filter { $0.url != nil }
        // The first detected editor is the default, so a choice is never empty.
        let selected = inspectState.exportEditorSelection[step.id]
            .flatMap { id in installed.first { $0.bundleId == id } } ?? installed.first
        let canBack = canGoBack(fromStepIndex: stepIndex) && (step.showBackButton ?? true)
        let destination = payload?.destination ?? "~/Documents"
        let doExport: () -> URL? = {
            do {
                return try CardExportEngine.performExport(items: items, destination: destination)
            } catch {
                writeLog("export step '\(step.id)': write failed — \(error.localizedDescription)",
                         logLevel: .error)
                return nil
            }
        }
        CardStepShell(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            hero: cardHero(step),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            accent: branding.primaryColor,
            footer: cardFooter(
                for: step, index: stepIndex,
                showBack: canBack,
                continueText: selected.map { "Create & Open in \($0.name)" } ?? "Create Files",
                secondaryText: payload?.revealButtonText ?? "Reveal in Finder",
                onSecondary: {
                    if let dest = doExport() {
                        NSWorkspace.shared.activateFileViewerSelecting([dest])
                    }
                }
            ) {
                guard let dest = doExport() else { return }
                if let editorURL = selected?.url {
                    NSWorkspace.shared.open([dest], withApplicationAt: editorURL,
                                            configuration: NSWorkspace.OpenConfiguration())
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([dest])
                }
                goToNextStep()
            }
        ) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: cardMetricsColGap) {
                        CardExportView(
                            measured: measured,
                            editors: editors,
                            selectedEditor: selected?.bundleId,
                            onSelectEditor: { inspectState.exportEditorSelection[step.id] = $0 },
                            accent: branding.primaryColor
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        CardPanelView(panel: InspectConfig.CardPanel(
                            caption: "WRITES TO",
                            stat: nil,
                            pairs: [InspectConfig.CardPanelPair(label: "Destination", value: destination),
                                    InspectConfig.CardPanelPair(label: "Total",
                                                                value: CardExportEngine.totalLabel(measured))]
                                + (selected.map { ed in [InspectConfig.CardPanelPair(
                                        label: "Editor detected",
                                        value: ed.version.map { v in "\(ed.name) \(v)" } ?? ed.name)] } ?? []),
                            image: nil, video: nil, imageTitle: nil, paragraphs: nil, layout: nil),
                            accent: branding.primaryColor)
                            .frame(width: 260, alignment: .topLeading)
                    }
                }
            }
        }
        .sourceTag()
    }
}
