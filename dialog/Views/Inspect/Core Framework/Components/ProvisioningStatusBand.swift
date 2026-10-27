//
//  ProvisioningStatusBand.swift
//  dialog
//
//  The one progress display on a provisioning screen: a count, live detail and a 3pt track, pinned
//  40 above the footer rule. Question screens show the choice's consequence in the same place instead.

import SwiftUI

/// What the band says; every screen has exactly one.
enum ProvisioningBandContent: Equatable {
    /// A task screen. `fraction` drives the track; `stopped` turns it red and stops it.
    case progress(count: String, detail: String?, fraction: Double, stopped: Bool)
    /// A question screen; no track.
    case consequence(text: String, detail: String?, swatch: Color?)
}

struct ProvisioningStatusBandBody: View {
    let content: ProvisioningBandContent
    /// nil fills the container, like `ProvisioningRowStack.width`. Taking a width rather than a
    /// `ProvisioningM` keeps the band usable outside the shell.
    let width: CGFloat?
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        switch content {
        case .progress(let count, let detail, let fraction, let stopped):
            progressBand(count: count, detail: detail, fraction: fraction, stopped: stopped)
        case .consequence(let text, let detail, let swatch):
            consequenceBand(text: text, detail: detail, swatch: swatch)
        }
    }

    // MARK: - Task screens

    /// The 740 × 44 strip at the shell's column, with no fill and no hairlines, matching the unfilled list.
    @ViewBuilder private func strip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: width, height: ProvisioningM.stripHeight)
            .frame(maxWidth: width == nil ? .infinity : nil)
    }

    private func progressBand(count: String, detail: String?, fraction: Double, stopped: Bool) -> some View {
        strip {
            VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                // A disabled primary always has this count beside it saying what would enable it.
                Text(count)
                    .font(.system(size: ProvisioningM.detailSize))
                    .foregroundStyle(palette.textMuted)
                Spacer(minLength: 0)
                if let detail {
                    // Mono: durations, sizes, waits. Count and eta are both 12.5 mono.
                    Text(detail)
                        .font(.system(size: ProvisioningM.detailSize, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                }
            }
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            // The bar sits at the strip's bottom so it never runs through the text baseline.
            Spacer(minLength: 0)
            // Only task screens pass a fraction, so question screens never draw a bar.
            track(fraction: fraction, stopped: stopped)
            }
            .padding(.vertical, 9)
        }
    }

    private func track(fraction: Double, stopped: Bool) -> some View {
        // Red only on the failed value and the stopped track.
        let fill = stopped ? palette.error : accent
        let clamped = min(max(fraction, 0), 1)
        // GeometryReader because a nil width fills the container; with a width it resolves to exactly that.
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ProvisioningM.trackRadius)
                    .fill(palette.text.opacity(0.18))
                    .frame(width: geo.size.width, height: ProvisioningM.trackHeight)
                RoundedRectangle(cornerRadius: ProvisioningM.trackRadius)
                    .fill(fill)
                    .frame(width: geo.size.width * clamped, height: ProvisioningM.trackHeight)
            }
        }
        .frame(width: width, height: ProvisioningM.trackHeight)
        .frame(maxWidth: width == nil ? .infinity : nil)
    }

    // MARK: - Question screens

    private func consequenceBand(text: String, detail: String?, swatch: Color?) -> some View {
        strip {
        HStack(spacing: 10) {
            if let swatch {
                // Brand colour at a competing size only here, where it is the subject; still a rounded square.
                RoundedRectangle(cornerRadius: 3)
                    .fill(swatch)
                    .frame(width: 12, height: 12)
            }
            Text(text)
                .font(.system(size: ProvisioningM.detailSize))
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
            Spacer(minLength: 16)
            if let detail {
                Text(detail)
                    .font(.system(size: ProvisioningM.detailSize, design: .monospaced))
                    .foregroundStyle(palette.textFaint)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        }
    }
}

/// The shell's band: the body at the column, pinned into the absolute bands. Takes the shell's
/// `ProvisioningM`, as `ProvisioningRowStack` / `ProvisioningRowList` split body and adapter.
struct ProvisioningStatusBand: View {
    let content: ProvisioningBandContent
    let metrics: ProvisioningM
    let accent: Color

    var body: some View {
        ProvisioningStatusBandBody(content: content, width: metrics.column, accent: accent)
            .offset(x: ProvisioningM.rail, y: metrics.stripTop)
    }
}
