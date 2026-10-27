//
//  Preset5+CardMedia.swift
//  dialog
//
//  The media arm: viewer, and the copy-left / clip-or-image-right split.
//

import SwiftUI

extension Preset5View {
    /// The card column gap; internal because the card arm files read it.
    var cardMetricsColGap: CGFloat { InspectMetrics.unit.cardColGap }

    /// The media arm: copy left, clip or image right. The source is `heroImage`, else the first
    /// `mediaItems` url. `mediaLayout: "viewer"` (or several items) renders the exclusive viewer.
    @ViewBuilder
    func cardMediaStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        let viewerItems = (step.mediaItems ?? []).compactMap { item -> CardMediaViewerItem? in
            guard let url = item.url else { return nil }
            return CardMediaViewerItem(path: resolvedMediaPath(url),
                                       title: item.title, caption: item.caption)
        }
        let wantsViewer = step.mediaLayout == "viewer"
            || (step.mediaLayout == nil && viewerItems.count > 1)
        if wantsViewer, !viewerItems.isEmpty {
            let idx = min(max(0, inspectState.cardSubStepIndex[step.id] ?? 0), viewerItems.count - 1)
            CardMediaViewerView(
                stepTitle: localized("title", forStep: step, fallback: step.title) ?? "",
                items: viewerItems,
                index: idx,
                accent: branding.primaryColor,
                onPrev: idx > 0 ? { inspectState.cardSubStepIndex[step.id] = idx - 1 } : nil,
                onNext: idx < viewerItems.count - 1
                    ? { inspectState.cardSubStepIndex[step.id] = idx + 1 } : nil,
                exitText: localized("continueButtonText", forStep: step,
                                    fallback: step.continueButtonText) ?? "Back to setup",
                onExit: {
                    inspectState.cardSubStepIndex[step.id] = 0
                    goToNextStep()
                },
                stageStyle: step.mediaStage
            )
            .sourceTag()
        } else {
            cardMediaSplitStepView(step: step, stepIndex: stepIndex)
        }
    }

    @ViewBuilder
    private func cardMediaSplitStepView(step: InspectConfig.IntroStep, stepIndex: Int) -> some View {
        if step.mediaRatio != nil {
            let _ = writeLog("card chrome: mediaRatio ignored on '\(step.id)' — the card's split "
                             + "is fixed so copy keeps one measure on every step", logLevel: .info)
        }
        let mediaPath = dynamicState.heroImageOverrides[step.id] ?? step.heroImage ?? step.mediaItems?.first?.url
        let isClip = mediaPath.map { p in
            ["gif", "mp4", "mov", "m4v"].contains((p as NSString).pathExtension.lowercased())
        } ?? false
        cardScreen(model: CardStepModel(
            eyebrow: config?.title,
            eyebrowIcon: config?.icon,
            stepLabel: cardStepLabel(stepIndex),
            title: localized("title", forStep: step, fallback: step.title) ?? "",
            subtitle: localized("subtitle", forStep: step, fallback: step.subtitle),
            blocks: cardBlocks(step),
            panel: localizedCardPanel(step) ?? mediaPath.map { path in
                InspectConfig.CardPanel(
                    caption: nil, stat: nil, pairs: nil,
                    image: isClip ? nil : path,
                    video: isClip ? path : nil,
                    imageTitle: nil, paragraphs: nil, layout: nil)
            },
            panelLeading: (step.mediaSide ?? "right").lowercased() == "left",
            footer: cardFooter(for: step, index: stepIndex) {
                openCardContinueActionURL(step.continueAction)
                goToNextStep()
            }
        ), stepId: step.id)
        .sourceTag()
    }
}
