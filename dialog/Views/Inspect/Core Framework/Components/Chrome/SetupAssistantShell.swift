//
//  SetupAssistantShell.swift
//  dialog
//
//  What the two Setup Assistant shells share: surface, ground, arrangement and content models,
//  their metrics and the footer row. The shells are SetupAssistantFullBleedShell (state α) and
//  SetupAssistantFramedShell (state β).
//

import SwiftUI

/// Which ground the footer stands on: α's colours are literals on a photograph, β's come from
/// the palette. Rails, heights and order are the same.
enum SetupAssistantSurface {
    case alpha
    case beta
}

/// Which way α's scrim ramps, and so which ink sits on it. `.light` closes the ramp to white and
/// takes its ink from the palette; named for the ground, not the appearance.
enum SetupAssistantGround {
    case dark
    case light

    var isDark: Bool { self == .dark }
}

/// How the α screen is arranged; orthogonal to the ground. `stack` is the bottom-anchored
/// column over the scrim; the others are selected by `contentAlign: "center"` or `layout`.
enum SetupAssistantArrangement {
    case stack
    /// A centred column at the top third, with an icon tile when the step authors a `heroImage`.
    case centered
    /// The centred column with the wait bar in it, under a floating status pill.
    case status
    /// A left-aligned header, then a feature grid or permission list (`layout: "features"` /
    /// `"permissions"`).
    case content
}

/// Which content model the `.content` arrangement draws.
enum SetupAssistantContent {
    case features([ProvisioningRowModel])
    case permissions([ProvisioningRowModel])

    static func resolve(_ layout: String?, rows: [ProvisioningRowModel]) -> SetupAssistantContent? {
        switch layout?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "features":    return .features(rows)
        case "permissions": return .permissions(rows)
        default:            return nil
        }
    }
}

/// Metrics for the centred, status and content arrangements.
enum SetupAssistantMetrics {
    static let tileSide: CGFloat = 88
    static let tileRadius: CGFloat = 20
    static let tileFillOpacity: CGFloat = 0.10
    static let tileStrokeOpacity: CGFloat = 0.20
    static let tileGlyph: CGFloat = 40
    static let columnTopWithTile: CGFloat = 180
    static let columnTop: CGFloat = 190
    static let columnTopStatus: CGFloat = 280
    static let tileGap: CGFloat = 28
    static let titleWithTile: CGFloat = 34
    static let title: CGFloat = 32
    static let titleGap: CGFloat = 10
    static let ledeSize: CGFloat = 15.5
    static let ledeMaxWidth: CGFloat = 480
    static let statusTop: CGFloat = 52
    static let statusHeight: CGFloat = 44
    static let statusPadH: CGFloat = 18
    static let statusGap: CGFloat = 10
    static let statusTitleSize: CGFloat = 13
    static let statusDetailSize: CGFloat = 11.5
    static let barWidth: CGFloat = 340
    static let barHeight: CGFloat = 3
    static let barGap: CGFloat = 24
    static let hintSize: CGFloat = 14
    // The dot rail (`stepCounterPlacement: "dots"`).
    static let dotsBottom: CGFloat = 108            // footer band + clearance
    static let dotHeight: CGFloat = 4
    static let dotWidth: CGFloat = 10
    static let dotActiveWidth: CGFloat = 22
    static let dotGap: CGFloat = 6
    static let dotIdleOpacity: CGFloat = 0.22
    /// The least air between the column and the rail.
    static let dotClearance: CGFloat = 24

    // The content arrangement: header at the top, content ending above the foot.
    static let contentTop: CGFloat = 56
    static let contentBottom: CGFloat = 100
    static let headerGap: CGFloat = 8
    static let headerBlockGap: CGFloat = 20
    static let tagHeight: CGFloat = 24
    static let tagPadH: CGFloat = 10
    static let tagRadius: CGFloat = 6
    static let tagSize: CGFloat = 11.5
    static let tagFillOpacity: CGFloat = 0.16
    static let contentTitleSize: CGFloat = 26
    static let contentLedeSize: CGFloat = 14.5
    static let contentLedeMaxWidth: CGFloat = 560
    // Feature cards
    static let featureColumns = 3
    static let featureGap: CGFloat = 14
    static let featureRadius: CGFloat = 12
    static let featureGlyphZone: CGFloat = 96
    static let featureGlyph: CGFloat = 30
    static let featureLabelSize: CGFloat = 13.5
    static let featureLabelPadH: CGFloat = 14
    static let featureLabelPadV: CGFloat = 12
    static let featureFillOpacity: CGFloat = 0.06
    static let featureStrokeOpacity: CGFloat = 0.10
    // Permission rows
    static let permissionTile: CGFloat = 40
    static let permissionTileRadius: CGFloat = 9
    static let permissionGlyph: CGFloat = 18
    static let permissionGap: CGFloat = 16
    static let permissionPadV: CGFloat = 16
    static let permissionTitleSize: CGFloat = 14.5
    static let permissionDetailSize: CGFloat = 12.5
    static let permissionTrailingSize: CGFloat = 13
    static let permissionDividerOpacity: CGFloat = 0.10

}

/// How the α ground is built, authored as the root `phaseBackground`; orthogonal to the ramp direction.
enum SetupAssistantGroundStyle: String {
    /// The picture (or `BrandGroundFallback`) under the scrim, copy in the scrim.
    case ramp
    /// A solid accent band with white ink from the top edge to the copy, a 1pt rule, then the
    /// window surface carrying the capsule and footer. No media, no scrim.
    case banded
    /// The window surface everywhere, palette ink, and no capsule box.
    case plain

    /// `.ramp` for anything unrecognised, including the gradient names other chromes read.
    static func resolve(_ authored: String?) -> SetupAssistantGroundStyle {
        switch authored?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "banded": return .banded
        case "plain": return .plain
        default: return .ramp
        }
    }
}

/// The standard footer row: mark, state line, doors, on a rule. One object for both surfaces,
/// and it never changes height, so nothing reflows between screens.
struct SetupAssistantFooter: View {
    let surface: SetupAssistantSurface
    /// Only consulted on α; β paints from the palette.
    var ground: SetupAssistantGround = .dark
    /// Absent, the row keeps its height and rule and the line starts at the rail.
    var logoPath: String?
    /// The only part of the row that changes between screens.
    var line: String?
    var primaryTitle: String?
    var primaryDisabled: Bool = false
    /// `holdPrimary: "hidden"`: the pill's seat stays empty so the other doors do not move.
    var primaryHidden: Bool = false
    var onPrimary: (() -> Void)?
    /// Full opacity on the banded ground, where a dimmed mark would not match its own band colour.
    var logoOpacity: Double = SetupAssistantM.footerLogoOpacity
    /// `logoConfig.maxHeight` when authored, capped by the seat at `footerLogoCap`.
    var logoHeight: CGFloat = SetupAssistantM.footerLogoHeight
    /// The step's `autoCloseAfter`, injected at the Preset 5 dispatch.
    @Environment(\.cardAutoClose) private var autoClose
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?
    /// Leftmost of the doors; nil draws none.
    var backLabel: String?
    var onBack: (() -> Void)?
    let accent: Color

    @Environment(\.palette) private var palette

    private var isAlpha: Bool { surface == .alpha }

    /// White on the dark ramp; the palette's text on the light one.
    private var alphaInk: Color { ground.isDark ? .white : palette.text }

    /// β uses the palette token, not a black literal: black at 8% is invisible on a dark window.
    private var ruleColor: Color {
        isAlpha ? alphaInk.opacity(SetupAssistantM.footerRuleAlpha)
                : palette.text.opacity(SetupAssistantM.footerRuleBeta)
    }

    private var lineColor: Color {
        isAlpha ? alphaInk.opacity(SetupAssistantM.footerLineAlpha) : palette.textFaint
    }

    private var quietPlate: Color {
        isAlpha ? alphaInk.opacity(SetupAssistantM.footerGhostAlpha) : palette.surfaceRaised
    }

    private var quietText: Color {
        isAlpha ? alphaInk.opacity(0.92) : palette.text
    }

    /// Three slots on the band: the mark, the line with its countdown, the doors.
    var body: some View {
        FooterRow(rail: SetupAssistantM.rail, rule: .over, ruleInk: ruleColor) {
            if let logoPath {
                BrandLogoImage(path: logoPath,
                               height: logoHeight,
                               opacity: logoOpacity)
                    .padding(.trailing, SetupAssistantM.footerGap)
            }
        } leading: {
            HStack(spacing: SetupAssistantM.footerGap) {
                if let line, !line.isEmpty {
                    Text(line)
                        .font(.system(size: SetupAssistantM.footerLineSize))
                        .foregroundStyle(lineColor)
                        // A wrap would grow the row.
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // The countdown fires the close itself; this row only seats it.
                if let autoClose {
                    CardAutoCloseCountdown(model: autoClose, ink: lineColor)
                }
            }
        } trailing: {
            doors
        }
    }

    /// Back, secondary, primary, left to right.
    private var doors: some View {
        HStack(spacing: SetupAssistantM.footerDoorGap) {
            if let backLabel {
                Door.back(plate: quietPlate, ink: quietText,
                          label: backLabel, action: { onBack?() })
                    .accessibilityLabel(backLabel)
            }
            if let secondaryTitle {
                Button { onSecondary?() } label: {
                    pill(secondaryTitle, fill: quietPlate, text: quietText)
                }
                .buttonStyle(.plain)
            }
            if let primaryTitle {
                Button { if !primaryDisabled { onPrimary?() } } label: {
                    pill(primaryTitle, fill: accent, text: .white)
                        .opacity(primaryDisabled ? SetupAssistantM.footerDisabledOpacity : 1)
                }
                .buttonStyle(.plain)
                .disabled(primaryDisabled || primaryHidden)
                // A hidden primary keeps its seat so the other doors stay put.
                .opacity(primaryHidden ? 0 : 1)
                .allowsHitTesting(!primaryHidden)
                .accessibilityHidden(primaryHidden)
                .keyboardShortcut(primaryHidden ? nil : .defaultAction)
            }
        }
    }

    private func pill(_ title: String, fill: Color, text: Color) -> some View {
        Text(title)
            .font(.system(size: SetupAssistantM.doorSize, weight: .semibold))
            .foregroundStyle(text)
            .lineLimit(1)
            .padding(.horizontal, SetupAssistantM.footerDoorPadH)
            .frame(height: SetupAssistantM.footerDoorHeight)
            .background(RoundedRectangle(cornerRadius: SetupAssistantM.footerDoorRadius,
                                         style: .continuous).fill(fill))
    }
}

/// What the screen's one capsule carries; an enum so a screen cannot carry two.
enum SetupAssistantCapsule: Equatable {
    /// The promises as marks; `met` is the only difference between the before and after screens.
    case marks(lines: [String], met: Bool)
    /// The wait screen's bar. `count` ("3 of 5") names the running phase when the bar stalls;
    /// the caller derives `fraction` from it so the two cannot disagree.
    case progress(text: String, count: String?, fraction: Double)
    /// The journey checklist. A carrier only: mark, status word and chip are decided by
    /// `ProvisioningRowBuilder` before they reach here.
    case checklist(rows: [ProvisioningRowModel])
    /// The same rows as a card grid (`layout: "grid"`). `total` is the item count the header
    /// states; nil counts the rows.
    case cardGrid(rows: [ProvisioningRowModel], total: Int?, columns: Int = JourneyGridM.columns, progress: Double? = nil, style: JourneyGridStyle = .tile, completed: Int? = nil)
    case none
}

/// Where a capped journey list scrolls to, and what counts as finished, as pure functions of
/// the rows so the counter and the scroll cannot disagree.
enum JourneyScroll {

    /// One instruction for `ScrollViewProxy.scrollTo(_:anchor:)`.
    struct Target: Equatable {
        let id: String
        let anchor: UnitPoint
    }

    /// Terminal means the mark the screen shows is done or failed. A skipped item draws as
    /// queued, so it is not terminal here either.
    static func isTerminal(_ row: ProvisioningRowModel) -> Bool {
        switch row.mark {
        case .done, .failed:            return true
        case .active, .queued, .choice, .check, .symbol: return false
        }
    }

    /// Centre the active row; stay put while work remains with no active row; once everything
    /// is terminal, show the last row at the bottom.
    static func target(rows: [ProvisioningRowModel]) -> Target? {
        guard let last = rows.last else { return nil }
        if let active = rows.first(where: { $0.mark == .active }) {
            return Target(id: active.id, anchor: .center)
        }
        guard rows.allSatisfy(isTerminal) else { return nil }
        return Target(id: last.id, anchor: .bottom)
    }

    /// "7 of 23 installed" while work remains; nil when every row is terminal, when there are
    /// no rows, or when the step sets `showProgressLine: false`, so the footer falls back to the
    /// authored `footerNote`. The denominator is the row count, never an authored number.
    static func progressLine(rows: [ProvisioningRowModel], noun: String,
                             enabled: Bool = true) -> String? {
        guard enabled else { return nil }
        guard !rows.isEmpty else { return nil }
        let finished = rows.filter(isTerminal).count
        guard finished < rows.count else { return nil }
        return "\(finished) of \(rows.count) \(noun)"
    }
}

/// Picks the email address out of the support line so it can take the accent. A trailing full
/// stop is not part of the match; a line with no address comes back unchanged.
enum SupportLineText {
    private static let pattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}"

    /// Every address in the line, in the order they appear.
    nonisolated static func emails(in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return re.matches(in: text, range: whole).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    /// The line with each address in `emphasis`, semibold.
    static func attributed(_ text: String, emphasis: Color, size: CGFloat) -> AttributedString {
        var line = AttributedString(text)
        for address in emails(in: text) {
            var search = line.startIndex..<line.endIndex
            while let found = line[search].range(of: address) {
                line[found].foregroundColor = emphasis
                line[found].font = .system(size: size, weight: .semibold)
                guard found.upperBound < line.endIndex else { break }
                search = found.upperBound..<line.endIndex
            }
        }
        return line
    }
}
