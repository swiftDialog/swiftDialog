//
// BentoStepViews.swift
// The configuration a bento step renders from, read by the Preset 5 bento arms.
//

import SwiftUI

// MARK: - Bento Step Configuration

/// Everything a bento step needs, extracted from an `IntroStep`.
struct BentoStepConfig {
    let title: String?
    let subtitle: String?
    let heroImage: String?
    let heroImageShape: String?
    let heroImageSize: Double?
    let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    let columns: Int
    let rowHeight: CGFloat
    let gap: CGFloat
    let tintColor: Color?
    let sidebarContent: [InspectConfig.GuidanceContent]?
    let sidebarRatio: CGFloat
    let layout: String  // "grid" | "hero" | "summary"
    let showSlots: Bool
    /// The step's `contentAnchor`, carried through to the shell.
    let stance: ContentStance

    /// `omitHeading` drops title, subtitle and hero when the hosting shell already draws them.
    init(from step: InspectConfig.IntroStep, accentColor: Color, stance: ContentStance = .centered,
         omitHeading: Bool = false) {
        self.title = omitHeading ? nil : step.title
        self.subtitle = omitHeading ? nil : step.subtitle
        self.heroImage = omitHeading ? nil : step.heroImage
        self.heroImageShape = step.heroImageShape
        self.heroImageSize = step.heroImageSize
        self.cells = step.bentoCells ?? []
        self.columns = step.bentoColumns ?? 2
        self.rowHeight = CGFloat(step.bentoRowHeight ?? 140)
        self.gap = CGFloat(step.bentoGap ?? 12)
        self.tintColor = step.bentoTintColor.flatMap { Color(hex: $0) }
        self.sidebarContent = step.bentoSidebarContent
        self.sidebarRatio = CGFloat(min(max(step.bentoSidebarRatio ?? 0.35, 0.25), 0.45))
        self.layout = step.bentoLayout ?? "grid"
        self.showSlots = step.bentoShowSlots ?? false
        self.stance = stance
    }
}
