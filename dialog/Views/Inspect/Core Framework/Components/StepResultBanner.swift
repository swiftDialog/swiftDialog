//
//  StepResultBanner.swift
//  dialog
//
//  The line a step ends on (failed, skipped or done), shared by Presets 5 and 6: tint, status disc,
//  title and reason, and an optional "Try again". Presets differ only in size and words.
//

import SwiftUI

struct StepResultBanner: View {
    enum Kind { case failure, skipped, success }

    /// The size a preset draws it at.
    struct Sizing {
        var icon: CGFloat
        var title: Font
        var detail: Font
        var padding: CGFloat
        var gap: CGFloat
        var radius: CGFloat

        /// Preset 5: the banner is the screen's result, so it is a full-size card.
        static let card = Sizing(icon: 32, title: .system(size: 16, weight: .semibold),
                                 detail: .system(size: 14), padding: 16, gap: 12, radius: 12)
        /// Preset 6: a row inside the step's content, sized by the preset's own metrics.
        static func inline(scale: CGFloat, gap: CGFloat) -> Sizing {
            Sizing(icon: 20 * scale, title: .body.weight(.semibold), detail: .caption,
                   padding: gap, gap: gap, radius: 8)
        }
    }

    let kind: Kind
    let title: String
    var detail: String?
    var sizing: Sizing = .card
    /// A flat receipt line with no tint or edge, for Preset 6's success where the rows already show the result.
    var flat = false
    /// "Try again", only on a failure and only when given.
    var retryTitle: String?
    var onRetry: (() -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: sizing.gap) {
            StatusIconView(icon, size: sizing.icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(sizing.title).foregroundStyle(.primary)
                if let detail, !detail.isEmpty {
                    Text(detail).font(sizing.detail).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if kind == .failure, let onRetry, let retryTitle {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .accessibilityElement(children: onRetry == nil ? .combine : .contain)
        .padding(flat ? EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0) : EdgeInsets(
            top: sizing.padding, leading: sizing.padding, bottom: sizing.padding, trailing: sizing.padding))
        .background(flat ? .clear : tint.background)
        .clipShape(RoundedRectangle(cornerRadius: sizing.radius))
        .overlay(RoundedRectangle(cornerRadius: sizing.radius)
            .stroke(tint.edge.opacity(flat ? 0 : 0.3), lineWidth: 1))
    }

    private var icon: StatusIconType {
        switch kind {
        case .failure: return .failure
        case .skipped: return .warning
        case .success: return .success
        }
    }

    private var tint: (background: Color, edge: Color) {
        switch kind {
        case .failure: return (palette.errorBackground, palette.error)
        case .skipped: return (palette.warningBackground, palette.warning)
        case .success: return (palette.successBackground, palette.success)
        }
    }
}
