//
//  PortalChrome.swift
//  dialog
//
//  The chrome around an embedded web view and the rules that decide its geometry. Plain value
//  types and leaf views only, shared by the portal step and the embedded web blocks: the page
//  always shows where it came from.
//

import SwiftUI

// MARK: - Layout

/// The portal step's layout key. Both values draw one web view with the readout, the browser
/// escape and the doors in the footer; the key still decodes so no config breaks.
enum PortalLayout: String, CaseIterable {
    case bar
    case footer

    init(_ raw: String?) {
        self = PortalLayout(rawValue: raw?.lowercased() ?? "") ?? .bar
    }

    /// The footer carries the browser escape; there is no title bar to carry it elsewhere.
    var footerRepeatsEscape: Bool { true }
}

// MARK: - Geometry

/// The viewport is derived from the window, never written as a literal.
enum PortalGeometry {
    /// The setup-assistant's standard footer row, read from there so the two stay one object.
    static var footerHeight: CGFloat { SetupAssistantM.footerHeight }

    /// Height available to the page. `layout` is accepted and ignored: every layout pays for the
    /// footer alone.
    static func viewportHeight(windowHeight: CGFloat, layout: PortalLayout) -> CGFloat {
        max(0, windowHeight - footerHeight)
    }

    /// Below roughly this width most sites serve their mobile layout, which is why the page has
    /// no horizontal inset.
    static let mobileBreakpoint: CGFloat = 700
}

// MARK: - Failure affordances

/// Which exits stay live when the page cannot load. A down page must never strand someone, so
/// Done is disabled only when a Skip can advance the flow instead.
struct PortalFailureAffordances: Equatable {
    let doneEnabled: Bool
    let skipEnabled: Bool
}

func portalFailureAffordances(hasSkip: Bool, isFailed: Bool) -> PortalFailureAffordances {
    guard isFailed else {
        return PortalFailureAffordances(doneEnabled: true, skipEnabled: hasSkip)
    }
    return PortalFailureAffordances(
        doneEnabled: !hasSkip,
        // Never disabled by a failure.
        skipEnabled: hasSkip
    )
}

// MARK: - What the URL chip says

/// Formatting for the address readout. A web view that hides its URL is the shape of a phishing
/// screen, so both forms are host-first and truncation can only eat the tail.
enum PortalURLDisplay {

    /// The full address, e.g. `https://github.com/macadmins`.
    static func full(_ url: URL) -> String {
        trimTrailingSlash(url.absoluteString)
    }

    /// Host and path only, e.g. `github.com/macadmins`.
    static func compact(_ url: URL) -> String {
        guard let host = url.host, !host.isEmpty else { return trimTrailingSlash(url.absoluteString) }
        return trimTrailingSlash(host + url.path)
    }

    /// The host alone, for the failure headline.
    static func host(_ url: URL) -> String {
        url.host ?? url.absoluteString
    }

    /// Only `https` earns the closed padlock.
    static func schemeSymbol(_ url: URL) -> String {
        url.scheme?.lowercased() == "https" ? "lock.fill" : "lock.slash"
    }

    static func isSecure(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    private static func trimTrailingSlash(_ s: String) -> String {
        s.count > 1 && s.hasSuffix("/") ? String(s.dropLast()) : s
    }
}

/// What the footer's leading slot carries; the brand text is the fallback for the fixed-height
/// row so a missing address is not a hole beside the doors.
enum PortalFooterLead: Equatable {
    case address
    case brandText
    case nothing
}

/// The address shows whenever there is one; there is no authored way to suppress it. `hasURL` is
/// false only until the first navigation resolves.
func portalFooterLead(hasURL: Bool, hasFooterText: Bool) -> PortalFooterLead {
    if hasURL { return .address }
    return hasFooterText ? .brandText : .nothing
}

// MARK: - One escape to the real browser

/// Says "Browser", not a named app: `NSWorkspace.open` hands the URL to the user's default handler.
enum PortalBrowserEscape {
    static let label = "Open in Browser"

    static func open(_ url: URL) {
        writeLog("PortalChrome: opening \(url.host ?? "url") in the default browser", logLevel: .debug)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - URL chip

struct PortalURLChip: View {
    @Environment(\.palette) private var palette

    enum Style {
        case bar        // inset field, full address: the embedded frame's strip
        case footer     // compact inset chip
        case overlay    // scrim capsule over a full-bleed page

        /// Colour decisions key on this, not on `== .bar`, so a new style cannot inherit the
        /// scrim's white-on-white by accident.
        var isOnScrim: Bool { self == .overlay }
    }

    let url: URL
    var style: Style = .bar
    var isLoading: Bool = false
    var accent: Color = .accentColor
    var scaleFactor: CGFloat = 1.0

    var body: some View {
        HStack(spacing: (style == .bar ? 7 : 8) * scaleFactor) {
            // The only moving element during load, in chrome that never resizes.
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .scaleEffect(0.6)
                    .frame(width: glyphSize, height: glyphSize)
                    .tint(style.isOnScrim ? .white : accent)
            } else {
                Image(systemName: PortalURLDisplay.schemeSymbol(url))
                    .font(.system(size: glyphSize * 0.9, weight: .medium))
                    .foregroundStyle(glyphColor)
                    .frame(width: glyphSize, height: glyphSize)
            }

            Text(style == .bar ? PortalURLDisplay.full(url) : PortalURLDisplay.compact(url))
                .font(.system(size: (style == .bar ? 11.5 : 11) * scaleFactor, design: .monospaced))
                .foregroundStyle(textColor)
                .lineLimit(1)
                // The host must never be the part an ellipsis replaces.
                .truncationMode(.tail)
        }
        .padding(.horizontal, (style == .bar ? 10 : 11) * scaleFactor)
        .frame(height: chipHeight)
        .background(chipBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Address")
        .accessibilityValue(PortalURLDisplay.full(url))
    }

    private var glyphSize: CGFloat { (style == .bar ? 11 : 10) * scaleFactor }

    /// The footer chip is the shortest of the three.
    private var chipHeight: CGFloat {
        switch style {
        case .bar: return 26 * scaleFactor
        case .footer: return 24 * scaleFactor
        case .overlay: return 30 * scaleFactor
        }
    }

    private var glyphColor: Color {
        if PortalURLDisplay.isSecure(url) {
            return style.isOnScrim ? .white.opacity(0.7) : palette.textMuted
        }
        return palette.warning
    }

    private var textColor: Color {
        style.isOnScrim ? .white.opacity(0.92) : palette.text.opacity(0.8)
    }

    @ViewBuilder
    private var chipBackground: some View {
        switch style {
        case .bar, .footer:
            RoundedRectangle(cornerRadius: 7 * scaleFactor)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 7 * scaleFactor)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
        case .overlay:
            RoundedRectangle(cornerRadius: 9 * scaleFactor)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - Browser escape button

struct PortalEscapeButton: View {

    let url: URL
    var style: PortalURLChip.Style = .bar
    var accent: Color = .accentColor
    var scaleFactor: CGFloat = 1.0

    var body: some View {
        Button {
            PortalBrowserEscape.open(url)
        } label: {
            Text("\(PortalBrowserEscape.label) ↗")
                .font(.system(size: (style == .footer ? 12 : 12.5) * scaleFactor, weight: .medium))
                .foregroundStyle(style.isOnScrim ? .white : accent)
                .lineLimit(1)
                .padding(.horizontal, style == .overlay ? 12 * scaleFactor : 0)
                .frame(height: style == .overlay ? 30 * scaleFactor : nil)
                .background {
                    if style == .overlay {
                        RoundedRectangle(cornerRadius: 9 * scaleFactor)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    }
                }
        }
        .buttonStyle(.plain)
        .help("\(PortalBrowserEscape.label) — \(PortalURLDisplay.host(url))")
        .accessibilityLabel(PortalBrowserEscape.label)
    }
}

// MARK: - The footer's address pill

/// The readout and the browser escape as one pill in the setup-assistant footer. The text
/// truncates at its tail and the escape keeps its width; the pill matches the doors' height.
struct PortalAddressPill: View {
    @Environment(\.palette) private var palette
    let url: URL
    var isLoading: Bool = false
    var accent: Color = .accentColor
    var scaleFactor: CGFloat = 1.0

    static let height: CGFloat = 34

    var body: some View {
        HStack(spacing: 10 * scaleFactor) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .scaleEffect(0.6)
                    .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
                    .tint(accent)
            } else {
                Image(systemName: PortalURLDisplay.schemeSymbol(url))
                    .font(.system(size: 11 * scaleFactor, weight: .medium))
                    .foregroundStyle(PortalURLDisplay.isSecure(url) ? palette.textMuted : palette.warning)
                    .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
            }
            Text(PortalURLDisplay.compact(url))
                .font(.system(size: 12.5 * scaleFactor, design: .monospaced))
                .foregroundStyle(palette.text.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
            Rectangle()
                .fill(palette.text.opacity(0.12))
                .frame(width: 1, height: 16 * scaleFactor)
            Button {
                PortalBrowserEscape.open(url)
            } label: {
                Text("\(PortalBrowserEscape.label) ↗")
                    .font(.system(size: 12.5 * scaleFactor, weight: .medium))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .help("\(PortalBrowserEscape.label) — \(PortalURLDisplay.host(url))")
            .accessibilityLabel(PortalBrowserEscape.label)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14 * scaleFactor)
        .frame(height: Self.height * scaleFactor)
        .background(Capsule().fill(palette.surfaceRaised))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Address")
        .accessibilityValue(PortalURLDisplay.full(url))
    }
}

// MARK: - Loading is a skeleton, not a spinner

/// Draws the page's shape while it loads so nothing resizes or re-centres when it arrives. Not
/// animated: the chip's ring already says "working".
struct PortalSkeletonView: View {

    var scaleFactor: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 11 * scaleFactor) {
            bar(height: 15, widthFraction: 0.58, radius: 4, opacity: 0.10)
            bar(height: 9, widthFraction: 0.88, radius: 3, opacity: 0.06)
            bar(height: 9, widthFraction: 0.74, radius: 3, opacity: 0.06)

            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(Color.primary.opacity(0.05))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16 * scaleFactor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading page")
    }

    private func bar(height: CGFloat, widthFraction: CGFloat,
                     radius: CGFloat, opacity: Double) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: radius * scaleFactor)
                .fill(Color.primary.opacity(opacity))
                .frame(width: geo.size.width * widthFraction, height: height * scaleFactor)
        }
        .frame(height: height * scaleFactor)
    }
}

// MARK: - Unreachable is a failed step

struct PortalFailureView: View {
    @Environment(\.palette) private var palette

    let failure: PortalLoadFailure
    let url: URL
    var fallbackMessage: String?
    var supportContact: String?
    var onRetry: () -> Void
    var scaleFactor: CGFloat = 1.0

    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 13 * scaleFactor) {
            ZStack {
                Circle().fill(palette.error)
                Text("!")
                    .font(.system(size: 19 * scaleFactor, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34 * scaleFactor, height: 34 * scaleFactor)

            VStack(spacing: 5 * scaleFactor) {
                Text("Can't reach \(failure.host ?? PortalURLDisplay.host(url))")
                    .font(.system(size: 16 * scaleFactor, weight: .semibold))

                Text(fallbackMessage ?? failure.message)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270 * scaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Omitted rather than invented when the failure carries no error code.
            if let diagnostic = failure.diagnostic {
                Text(diagnostic)
                    .font(.system(size: 11 * scaleFactor, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 9 * scaleFactor) {
                Button(ChromeCopy.tryAgain, action: onRetry)
                    .buttonStyle(.bordered)

                Button(didCopy ? "Copied" : "Copy link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    didCopy = true
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)

            if let supportContact {
                Text(supportContact)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Embedded frame (guidance blocks)

/// A `webcontent` or `portal-webview` block: a strip with the address and the escape, the
/// skeleton while loading, the failure view when it cannot load. Security affordances only, none
/// of the step chrome.
struct EmbeddedWebFrame: View {

    let url: URL
    var openExternalLinksInBrowser: Bool = true
    var height: CGFloat = 400
    var accent: Color = .accentColor
    var scaleFactor: CGFloat = 1.0

    @State private var loadState: PortalLoadState = .initializing
    @State private var liveURL: URL?
    @State private var viewId = UUID()

    @Environment(\.palette) private var palette

    private var shownURL: URL { liveURL ?? url }

    var body: some View {
        VStack(spacing: 0) {
            // Never conditional: the frame never shows a page without saying where it came from.
            HStack(spacing: 8 * scaleFactor) {
                PortalURLChip(url: shownURL, style: .bar,
                              isLoading: loadState == .loading || loadState == .initializing,
                              accent: accent, scaleFactor: scaleFactor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PortalEscapeButton(url: shownURL, style: .bar,
                                   accent: accent, scaleFactor: scaleFactor)
            }
            .padding(.horizontal, 8 * scaleFactor)
            .frame(height: 34 * scaleFactor)

            ZStack {
                PortalWebView(
                    url: url,
                    openExternalLinksInBrowser: openExternalLinksInBrowser,
                    onLoadStateChange: { state in
                        withAnimation(.easeInOut(duration: 0.2)) { loadState = state }
                    },
                    onURLChange: { liveURL = $0 }
                )
                .id(viewId)

                // Replaces rather than dims: a dimmed half-painted page is its own flicker.
                if loadState == .loading || loadState == .initializing {
                    PortalSkeletonView(scaleFactor: scaleFactor)
                }

                if let failure = loadState.failure {
                    PortalFailureView(
                        failure: failure,
                        url: shownURL,
                        onRetry: {
                            loadState = .loading
                            viewId = UUID()
                        },
                        scaleFactor: scaleFactor
                    )
                }

                if loadState == .offline {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "wifi.slash").foregroundStyle(palette.warning)
                            Text("Viewing cached content")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(palette.warning.opacity(0.1))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
