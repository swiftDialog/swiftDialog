//
//  RailStepComponents.swift
//  dialog
//
//  The rail chrome (config "chrome": "rail"): the card design language with a persistent left rail
//  instead of footer dots, designed at `RailM.window`. Shares substeps, content blocks, media, badges
//  and `FooterActionCluster` with the card system.

import SwiftUI
import AVKit


enum RailM {
    /// The reference window `measureScale` is pinned to; a plain constant, since scaling it would be circular.
    static let window = CGSize(width: 820, height: 560)
}

/// Rail row state; geometry is identical across states. .failed beats .done, since the engine
/// records failed steps in both failedSteps and completedSteps.
enum RailState { case active, done, pending, failed }

struct RailRowModel: Identifiable {
    let id: String
    let label: String
    let state: RailState
    let number: Int                 // 1-based numeral for active/pending glyphs
}

/// Everything the left rail shows.
struct RailChromeModel {
    var orgLabel: String?           // uppercase 11/semibold kerned
    var brandIcon: String?          // "SF=symbol" or path — 20×20 mark
    var stepIcon: String?           // context-aware step icon on top (current item's `icon`)
    var progress: Double            // 0…1 capsule fill
    var doneLabel: String           // "1 of 2 completed"
    var rows: [RailRowModel]
    var logoPath: String?           // bottom logo, 0.9 opacity
    var logoHeight: CGFloat = 24    // logoConfig.maxHeight (band height incl. clear space)
    var logoClearSpace: CGFloat = 0 // logoConfig.logoClearSpace (brand margin fraction)
}

/// Footer for the content column: right-aligned actions (the shared `FooterActionCluster`), or a
/// footnote left with actions right.
struct RailFooterModel {
    var footnote: String?               // Markdown; when set, replaces the Later slot
    var backText: String?               // nil → no Back; Back is always labelled
    var onBack: (() -> Void)?
    var secondaryText: String?
    var onSecondary: (() -> Void)?
    var continueText: String?           // nil or "" → no primary (the card's rule, shared)
    var continueDisabled: Bool = false
    var onContinue: () -> Void
    var inspectConfig: InspectConfig?
    var deferralText: String?
}

/// A baseline-aligned label/value row for the rail facts panel:
/// label 12.5 secondary leading — Spacer — value 13.5/semibold trailing.
struct RailFactRow: Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

/// Language row: an inline Menu styled to match the fact rows.
struct RailLanguageRow {
    var label: String               // "Language"
    var options: [String]
    var current: String
    var onSelect: (String) -> Void
}

/// The stall escape, shown only after the stall timeout. Bordered, not filled, so it does not
/// read as the recommended path.
struct RailEscapeModel {
    var headline: String            // "Still waiting on enrollment"
    var consequence: String         // what skipping means
    var skipText: String            // "Skip this step"
    var onSkip: () -> Void
}

/// Content-column model for one rail step.
struct RailStepModel {
    var stepLabel: String?          // "Step 2 of 4" — 12/medium monospaced
    var title: String
    var titleBadge: Bool = false    // 30pt badge beside the title
    var titleBadgeFailed: Bool = false  // red badge — finished with failures
    var statusPill: String?   // pill below the title
    var statusPillFailed: Bool = false  // red pill for user-marked failure
    var subtitle: String?
    var progress: Double?     // 5pt capsule attached to the header
    var blocks: [InspectConfig.GuidanceContent] = []
    var substeps: [(state: CardSubstepState, label: String)]?   // wins over blocks
    var facts: [RailFactRow]?       // baseline-row panel
    var media: InspectConfig.CardPanel?   // instruction clip or screenshot, without chrome
    var mediaMax: Bool = false      // media-hero step: player fills the column ("Watch this once")
    var mediaCaption: String?       // amber single-line note under the player
    var languageRow: RailLanguageRow?
    var paragraphs: [String]?       // reassurance copy, 13.5pt
    var failures: [(label: String, detail: String?)] = []   // failed steps in the listing
    var escape: RailEscapeModel?
    var footer: RailFooterModel
}

// MARK: - Shell

/// The rail's generic half, like `CardStepShell`: rail plus an arbitrary payload column (e.g. a bento
/// layout). `RailStepScreen` is the model-driven half built on it.
struct RailStepShell<Content: View>: View {
    @Environment(\.palette) private var palette
    let rail: RailChromeModel
    let accent: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            RailView(rail: rail, accent: accent)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.cardSurface)
    }
}

// MARK: - Screen

struct RailStepScreen: View {
    @Environment(\.palette) private var palette
    /// The help control, on the step-label line when the preset provides one (optional).
    @Environment(\.cardHeaderHelp) private var help
    let rail: RailChromeModel
    let model: RailStepModel
    let accent: Color
    @ObservedObject var inspectState: InspectState
    let scaleFactor: CGFloat
    let iconBasePath: String?
    let stepId: String

    var body: some View {
        RailStepShell(rail: rail, accent: accent) { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: InspectMetrics.unit.railContentGap) {
            header
            body_
            if let media = model.media {
                // Media takes the leftover height so the footer stays pinned; movies get playback
                // controls, GIFs loop.
                GeometryReader { geo in
                    if model.mediaMax, let clip = media.video,
                       !clip.lowercased().hasSuffix(".gif"),
                       FileManager.default.fileExists(atPath: clip) {
                        RailVideoPlayer(path: clip, accent: accent)
                            .frame(height: max(60, geo.size.height))
                    } else {
                        CardMediaSection(panel: media, accent: accent,
                                         maxHeight: max(60, min(model.mediaMax ? 340 : 220,
                                                                geo.size.height)),
                                         maxWidth: geo.size.width)
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
            if let note = model.mediaCaption {
                CardWarningLine(text: note)
            }
            RailFooterView(footer: model.footer, accent: accent)
        }
        .padding(.init(top: InspectMetrics.unit.railContentTop, leading: InspectMetrics.unit.railContentLeading,
                       bottom: InspectMetrics.unit.railContentBottom, trailing: InspectMetrics.unit.railContentTrailing))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.stepLabel != nil || help != nil {
                HStack(spacing: 0) {
                    if let stepLabel = model.stepLabel {
                        Text(stepLabel)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.text.opacity(0.44))
                    }
                    if let help {
                        Spacer(minLength: 12)
                        HelpGlyphButton(icon: help.icon, tooltip: help.tooltip, tint: accent,
                                        action: help.action)
                            .preference(key: CardHeaderHelpSeatedKey.self, value: true)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                if model.titleBadge {
                    HStack(spacing: 13) {
                        StatusTitleBadge(failed: model.titleBadgeFailed)
                        titleText
                    }
                } else {
                    titleText
                }
                if let pill = model.statusPill {
                    RailStatusPill(text: pill, failed: model.statusPillFailed)
                }
                if let subtitle = model.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14.5))
                        .foregroundStyle(palette.text.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: InspectMetrics.unit.railSubtitleMax, alignment: .leading)
                }
            }
            if let progress = model.progress {
                AccentProgressCapsule(progress: progress, accent: accent)
            }
        }
    }

    private var titleText: some View {
        Text(model.title)
            .font(.system(size: InspectMetrics.unit.railTitleSize, weight: .bold))
            .tracking(-0.594)
            .foregroundStyle(palette.text.opacity(0.9))
    }

    @ViewBuilder private var body_: some View {
        if let substeps = model.substeps {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(substeps.indices, id: \.self) { i in
                    CardSubstepRow(state: substeps[i].state,
                                   label: substeps[i].label,
                                   accent: accent)
                }
            }
        } else if !model.blocks.isEmpty || !model.failures.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                CardContentBlocks(blocks: model.blocks,
                                  accent: accent,
                                  inspectState: inspectState,
                                  scaleFactor: scaleFactor,
                                  iconBasePath: iconBasePath,
                                  stepId: stepId)
                ForEach(model.failures.indices, id: \.self) { i in
                    CardSubstepRow(state: .failed,
                                   label: model.failures[i].detail.map {
                                       "\(model.failures[i].label) — \($0)"
                                   } ?? model.failures[i].label,
                                   accent: accent)
                }
            }
        }
        if let facts = model.facts {
            RailFactsPanel(rows: facts, languageRow: model.languageRow, accent: accent)
        }
        if let paragraphs = model.paragraphs, !paragraphs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(paragraphs.indices, id: \.self) { i in
                    Text(guidanceAttributedMarkdown(paragraphs[i]))
                        .font(.system(size: 13.5))
                        .foregroundStyle(palette.text.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if let escape = model.escape {
            RailEscapeHatch(model: escape)
        }
    }
}

// MARK: - The rail

struct RailView: View {
    @Environment(\.palette) private var palette
    let rail: RailChromeModel
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Shown only when the current item declares an `icon`.
            if let icon = rail.stepIcon {
                RailStepIconView(icon: icon, accent: accent)
                    .padding(.horizontal, InspectMetrics.unit.railChildPad)
                    .padding(.bottom, 14)
                    .id("rail-step-icon-\(icon)")
                    .transition(.opacity)
            }
            HStack(spacing: 8) {
                SmallBrandMark(icon: rail.brandIcon, accent: accent)
                if let org = rail.orgLabel {
                    Text(org.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.5)
                        .foregroundStyle(palette.text.opacity(0.6))
                }
            }
            .padding(.horizontal, InspectMetrics.unit.railChildPad)

            VStack(alignment: .leading, spacing: 7) {
                AccentProgressCapsule(progress: rail.progress, accent: accent, height: 4)
                Text(rail.doneLabel)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.text.opacity(0.44))
            }
            .padding(.top, 18)
            .padding(.horizontal, InspectMetrics.unit.railChildPad)

            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, InspectMetrics.unit.railChildPad)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(rail.rows) { row in
                    RailRowView(row: row, accent: accent)
                }
            }

            Spacer(minLength: 0)

            if let logo = rail.logoPath, let trimmed = LogoTrimCache.image(for: logo) {
                // Width-fit so a very wide wordmark never pushes the fixed-width rail off the window.
                let innerWidth = InspectMetrics.unit.railWidth - 2 * InspectMetrics.unit.railPad - 2 * InspectMetrics.unit.railChildPad
                let aspect = max(0.1, trimmed.size.width / max(1, trimmed.size.height))
                // Clamped here too because this value also feeds `bandHeight`.
                let clearSpace = min(max(rail.logoClearSpace, 0), 0.6)
                let markFitHeight = innerWidth / aspect
                // Authored maxHeight honoured up to 32pt; the width-fit clamps wide marks.
                let bandHeight = min(rail.logoHeight, 32,
                                     markFitHeight / max(0.01, 1 - clearSpace * 2))
                BrandLogoImage(path: logo, height: bandHeight, clearSpace: clearSpace)
                    .opacity(0.9)
                    .padding(.horizontal, InspectMetrics.unit.railChildPad)
                    .accessibilityHidden(true)
            }
        }
        .padding(InspectMetrics.unit.railPad)
        .frame(width: InspectMetrics.unit.railWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(palette.text.opacity(0.016))   // the rail's ground, from the palette
        .overlay(alignment: .trailing) {
            Rectangle().fill(palette.text.opacity(0.08)).frame(width: 0.5)
        }
    }
}

/// One rail row, three states, identical geometry.
private struct RailRowView: View {
    @Environment(\.palette) private var palette
    let row: RailRowModel
    let accent: Color

    var body: some View {
        HStack(spacing: 11) {
            glyph.frame(width: 19, height: 19)
            Text(row.label)
                .font(.system(size: 13.5, weight: row.state == .active ? .semibold : .regular))
                .foregroundStyle(labelColor)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, InspectMetrics.unit.railChildPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(row.state == .active ? accent : .clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder private var glyph: some View {
        switch row.state {
        case .active:
            ZStack {
                Circle().fill(Color.white.opacity(0.26))
                Text("\(row.number)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white, accent)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white, palette.error)
        case .pending:
            ZStack {
                Circle().strokeBorder(palette.text.opacity(0.137), lineWidth: 1.5)
                Text("\(row.number)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.text.opacity(0.31))
            }
        }
    }

    private var labelColor: Color {
        switch row.state {
        case .active: return .white
        case .done, .failed: return palette.text.opacity(0.55)
        case .pending: return palette.text.opacity(0.32)
        }
    }
}

/// 44pt tinted rounded-square step icon: "SF=symbol", a bare SF Symbol name, or an image path.
private struct RailStepIconView: View {
    let icon: String
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.12))
            if FileManager.default.fileExists(atPath: icon),
               let nsImage = InspectImageCache.shared.image(atPath: icon) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: IconRef.symbolOrBareName(icon) ?? icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Content-column pieces

/// Confirmation pill that hugs its content so the 36pt text edge holds. Green for success, red for failure.
struct RailStatusPill: View {
    @Environment(\.palette) private var palette

    let text: String
    var failed: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(failed ? palette.error : palette.success)
                Image(systemName: failed ? "xmark" : "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 14, height: 14)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(failed ? palette.errorInk : palette.successInk)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Capsule().fill(failed ? palette.errorBackground
                                          : palette.successBackground))
        .fixedSize()
    }
}

/// Baseline-aligned facts panel: label leading, value trailing, hairlines between; the language row
/// is an inline Menu matched to the rhythm.
struct RailFactsPanel: View {
    @Environment(\.palette) private var palette
    let rows: [RailFactRow]
    var languageRow: RailLanguageRow?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows.indices, id: \.self) { i in
                if i > 0 { hairline }
                HStack(alignment: .firstTextBaseline) {
                    Text(rows[i].label)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.text.opacity(0.5))
                    Spacer()
                    Text(rows[i].value)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(palette.text.opacity(0.9))
                }
            }
            if let lang = languageRow {
                if !rows.isEmpty { hairline }
                HStack(alignment: .firstTextBaseline) {
                    Text(lang.label)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.text.opacity(0.5))
                    Spacer()
                    Menu {
                        ForEach(lang.options, id: \.self) { option in
                            Button(option) { lang.onSelect(option) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(lang.current)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(palette.text.opacity(0.9))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(palette.text.opacity(0.45))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.text.opacity(0.035)))
    }

    private var hairline: some View {
        Rectangle().fill(palette.text.opacity(0.09))
            .frame(height: 0.5).frame(maxWidth: .infinity)
    }
}

/// The stall escape hatch: a bordered skip button, because skipping is not the recommended path.
struct RailEscapeHatch: View {
    @Environment(\.palette) private var palette

    let model: RailEscapeModel

    /// Instance properties, not `static let`: a static cannot read `\.palette`.
    private var ink: Color { palette.warningInk }
    private var softInk: Color { palette.warningInk.opacity(0.8) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.headline)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(ink)
                if !model.consequence.isEmpty {
                    Text(model.consequence)
                        .font(.system(size: 13))
                        .foregroundStyle(softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button(action: model.onSkip) {
                Text(model.skipText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.cardSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(ink.opacity(0.35), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.warningBackground)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ink.opacity(0.25), lineWidth: 0.5))
        )
    }
}

/// Media player with controls for "watch this once" steps; no autoplay.
struct RailVideoPlayer: View {
    @Environment(\.palette) private var palette
    let path: String
    let accent: Color

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if player == nil { player = AVPlayer(url: URL(fileURLWithPath: path)) }
            }
            .onDisappear { player?.pause() }
            .background(palette.text.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
    }
}

/// The warning copy as a single amber line, no box, for media-max steps.
struct CardWarningLine: View {
    @Environment(\.palette) private var palette

    let text: String

    private var warnInk: Color { palette.warningInk }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(warnInk)
            Text(guidanceAttributedMarkdown(text))
                .font(.system(size: 13))
                .foregroundStyle(warnInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Footer: the shared `FooterActionCluster` right-aligned, or footnote left with actions right.
struct RailFooterView: View {
    @Environment(\.palette) private var palette
    let footer: RailFooterModel
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            if let note = footer.footnote {
                StateLine(text: note)
            }
            Spacer()
            FooterActionCluster(
                actions: FooterActionsModel(backText: footer.backText,
                                            onBack: footer.onBack,
                                            secondaryText: footer.secondaryText,
                                            onSecondary: footer.onSecondary,
                                            continueText: footer.continueText,
                                            continueDisabled: footer.continueDisabled,
                                            onContinue: footer.onContinue,
                                            inspectConfig: footer.footnote == nil
                                                ? footer.inspectConfig : nil,
                                            deferralText: footer.deferralText),
                accent: accent)
        }
        .padding(.top, 22)
    }
}
