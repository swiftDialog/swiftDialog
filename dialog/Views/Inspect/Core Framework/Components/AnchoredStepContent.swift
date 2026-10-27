//
//  AnchoredStepContent.swift
//  dialog
//
//  The vertical-anchoring and overflow-scroll shell for every full-screen step, so
//  `contentAnchor: "top"` means the same offset on every screen.
//

import SwiftUI

/// The banded layout's geometry, in unscaled points multiplied by `measureScale`.
enum StepBandMetrics {
    /// The header band's cap and first-pass fallback. The band is sized to the measured header,
    /// never taller than this; a header shorter than the cap already gets its own height.
    static let header: CGFloat = 184
    /// The pinned action bar. Not drawn here; the viewport height this view receives excludes it.
    static let actionBar: CGFloat = 76
    /// The hero's visible mark.
    static let hero: CGFloat = 64

    /// What to pass `IntroHeroImage(size:)` for a 64pt mark: that parameter sizes the container
    /// and the mark comes out at roughly 0.4 of it.
    static let heroContainer: CGFloat = 160
    /// Body-copy measure.
    static let measure: CGFloat = 520
}

/// The header band's natural height, reported up from the caller's header builder. `max` so a
/// builder emitting two measured subtrees reports the taller.
private struct BandHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Where a step's content group is pinned vertically.
enum StepAnchor: String {
    /// Balanced spacers center the group (default).
    case center
    /// The first content element sits at exactly `metrics.anchorTopInset`, so hero, title and
    /// subtitle hold one position across sibling steps.
    case top
    /// A header band, then the payload in what is left. A mode of the stack, not a nested view;
    /// requires the `bands:` init.
    case bands

    /// Unknown values and nil fall back to `.center`; matching ignores case.
    init(configValue: String?) {
        self = StepAnchor(rawValue: configValue?.lowercased() ?? "") ?? .center
    }
}

/// Owns a step's vertical anchoring and overflow scrolling. The first content element's minimum
/// top offset is `metrics.anchorTopInset` in both modes (exact in `.top`, the minimum before slack
/// distributes in `.center`); content scrolls on overflow. The top slot is sized
/// `anchorTopInset − spacing` so the stack gap completes the figure whatever the spacing is.
struct AnchoredStepContent: View {
    var anchor: StepAnchor = .center
    let metrics: InspectMetrics
    /// nil uses `metrics.contentPadH`; pass 0 when the content blocks pad themselves.
    var horizontalPadding: CGFloat?
    /// Where content narrower than the width rests. A left-oriented step passes `.leading` so
    /// hero, buttons and short rows share one text edge.
    var alignment: HorizontalAlignment = .center
    /// Spacing of the content VStack; nil uses `metrics.sectionGap`.
    var spacing: CGFloat?
    /// Spacers take their minimum first and split the remainder, so the default asymmetric top
    /// minimum biases content down by half the slot. `true` centres exactly (bookend screens).
    var symmetricCenter: Bool = false
    /// Bottom fade and chevron on overflow. Defaults on because an overflowing step otherwise
    /// clips silently; the overlay draws nothing when the content fits.
    var scrollHint: Bool = true
    /// Header-band height in unscaled points; only consulted in `.bands`.
    var bandHeaderHeight: CGFloat = StepBandMetrics.header
    /// Type-erased so huge step-body tuple types stay out of this shell's generics. The builder
    /// receives the viewport height; the plain `content:` init ignores it.
    private let content: (CGFloat) -> AnyView
    /// `.bands` only; nil in every other mode.
    private let header: ((CGFloat) -> AnyView)?

    @State private var hintContentHeight: CGFloat = 0
    @State private var hintScrollOffset: CGFloat = 0
    /// 0 until the first layout pass, when `bandHeaderHeight` is the fallback.
    @State private var measuredHeaderHeight: CGFloat = 0

    init(
        anchor: StepAnchor = .center,
        alignment: HorizontalAlignment = .center,
        metrics: InspectMetrics,
        horizontalPadding: CGFloat? = nil,
        spacing: CGFloat? = nil,
        symmetricCenter: Bool = false,
        scrollHint: Bool = true,
        @ViewBuilder content: () -> some View
    ) {
        self.anchor = anchor
        self.metrics = metrics
        self.horizontalPadding = horizontalPadding
        self.alignment = alignment
        self.spacing = spacing
        self.symmetricCenter = symmetricCenter
        self.scrollHint = scrollHint
        let built = AnyView(content())
        self.content = { _ in built }
        self.header = nil
    }

    /// The builder runs per layout pass with the current viewport height.
    init(
        anchor: StepAnchor = .center,
        alignment: HorizontalAlignment = .center,
        metrics: InspectMetrics,
        horizontalPadding: CGFloat? = nil,
        spacing: CGFloat? = nil,
        symmetricCenter: Bool = false,
        scrollHint: Bool = true,
        viewportContent: @escaping (CGFloat) -> some View
    ) {
        self.anchor = anchor
        self.metrics = metrics
        self.horizontalPadding = horizontalPadding
        self.alignment = alignment
        self.spacing = spacing
        self.symmetricCenter = symmetricCenter
        self.scrollHint = scrollHint
        self.content = { AnyView(viewportContent($0)) }
        self.header = nil
    }

    /// Bands mode. A separate init so `.bands` without a header is unrepresentable.
    init(
        bands metrics: InspectMetrics,
        alignment: HorizontalAlignment = .center,
        horizontalPadding: CGFloat? = nil,
        headerHeight: CGFloat = StepBandMetrics.header,
        scrollHint: Bool = true,
        @ViewBuilder header: () -> some View,
        @ViewBuilder payload: () -> some View
    ) {
        self.anchor = .bands
        self.metrics = metrics
        self.alignment = alignment
        self.horizontalPadding = horizontalPadding
        self.spacing = nil
        self.symmetricCenter = false
        self.scrollHint = scrollHint
        self.bandHeaderHeight = headerHeight
        let builtHeader = AnyView(header())
        let builtPayload = AnyView(payload())
        self.header = { _ in builtHeader }
        self.content = { _ in builtPayload }
    }

    private var stackSpacing: CGFloat { spacing ?? metrics.sectionGap }
    private var topSlot: CGFloat { max(0, metrics.anchorTopInset - stackSpacing) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollView {
                    anchoredStack(viewportHeight: geo.size.height)
                }
                .scrollIndicators(.automatic)
                // Read off the ScrollView itself; a preference inside the stack measures 0 here.
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height
                } action: { _, newHeight in
                    hintContentHeight = newHeight
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newOffsetY in
                    // `ScrollHintOverlay` expects the `.frame(in:).minY` sign (negative when
                    // scrolled); `contentOffset.y` is the opposite.
                    hintScrollOffset = -newOffsetY
                }

                if scrollHint {
                    ScrollHintOverlay(
                        containerHeight: geo.size.height,
                        contentHeight: hintContentHeight,
                        scrollOffset: hintScrollOffset
                    )
                }
            }
            .onPreferenceChange(BandHeaderHeightKey.self) { measuredHeaderHeight = $0 }
        }
    }

    @ViewBuilder
    private func anchoredStack(viewportHeight: CGFloat) -> some View {
        if anchor == .bands, let header {
            bandedStack(viewportHeight: viewportHeight, header: header)
        } else {
            classicStack(viewportHeight: viewportHeight)
        }
    }

    /// Header band sized to the measured header (capped), then the payload band reserving at
    /// least the rest of the viewport, top-aligned one `sectionGap` below. A taller payload grows
    /// the stack past the viewport and the ScrollView scrolls it.
    private func bandedStack(viewportHeight: CGFloat,
                             header: @escaping (CGFloat) -> AnyView) -> some View {
        // The header is top-aligned in its band, so hero and title hold one y across steps
        // whatever the band's height; only the payload moves up.
        let designBand = bandHeaderHeight * metrics.measureScale
        let headerBand = measuredHeaderHeight > 0 ? min(measuredHeaderHeight, designBand) : designBand
        return VStack(alignment: alignment, spacing: 0) {
            VStack(alignment: alignment, spacing: 0) { header(viewportHeight) }
                // `.fixedSize` before the frame, or the GeometryReader measures the clamped band
                // and reports the cap forever.
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: BandHeaderHeightKey.self, value: g.size.height)
                    }
                )
                .frame(height: headerBand, alignment: .top)

            // Top-aligned with the composition's own gap: centring opens dead air under the
            // subtitle, and no gap reads as one run-on block.
            VStack(alignment: alignment, spacing: 0) {
                content(viewportHeight)
                Spacer(minLength: 0)
            }
            .padding(.top, metrics.sectionGap)
            // `minHeight`, not `height`: a fixed height would pin the band and a tall payload
            // would bleed out of it with nothing to scroll. Inside a ScrollView the frame's `.top`
            // alignment, not the trailing Spacer, places a short payload.
            .frame(minHeight: max(0, viewportHeight - headerBand), alignment: .top)
        }
        .padding(.horizontal, horizontalPadding ?? metrics.contentPadH)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func classicStack(viewportHeight: CGFloat) -> some View {
        let stack = VStack(alignment: alignment, spacing: stackSpacing) {
            switch anchor {
            case .top:
                Color.clear.frame(height: topSlot)
            case .center:
                Spacer(minLength: symmetricCenter ? 0 : topSlot)
            case .bands:
                // Routed to bandedStack before this switch; kept so the switch stays exhaustive.
                EmptyView()
            }
            content(viewportHeight)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, horizontalPadding ?? metrics.contentPadH)
        // Inside a ScrollView this frame does not propose its min height down, so the stack
        // renders at natural height and the alignment is what implements the anchor.
        .frame(maxWidth: .infinity, minHeight: viewportHeight,
               alignment: anchor == .top ? .top : .center)

        stack
    }
}
