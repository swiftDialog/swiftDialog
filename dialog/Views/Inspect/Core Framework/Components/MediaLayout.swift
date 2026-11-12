//
//  MediaLayout.swift
//  Dialog
//
//  How media occupies the payload band.
//

import SwiftUI

/// The authored `mediaLayout` key: `fill` gives the picture the whole band and moves its caption
/// to the action bar, `split` seats a fixed media box beside the other content, `inline` (the
/// default) keeps media as one block in the stack.
enum MediaLayout: String, Equatable {
    case fill
    case split
    case inline

    /// Unknown or missing values fall back to `inline`.
    static func resolve(_ authored: String?) -> MediaLayout {
        guard let authored, !authored.isEmpty,
              let value = MediaLayout(rawValue: authored.lowercased()) else { return .inline }
        return value
    }

    /// Whether the picture owns the payload band rather than sitting in the stack.
    var takesTheBand: Bool { self != .inline }

    /// In `fill` the caption is drawn on the action bar so the band stays undivided.
    var captionBelongsOnTheBar: Bool { self == .fill }
}

/// How a step's blocks occupy the payload band, decided once per step. Pure over the block list
/// so it can be tested without rendering.
enum MediaArrangement: Equatable {
    /// Every block in one vertical stack.
    case stacked
    /// One media block is the band; its caption moves to the action bar.
    case fill(index: Int)
    /// A fixed media box beside everything else on the step.
    case split(mediaIndex: Int)

    static func resolve(_ blocks: [InspectConfig.GuidanceContent]) -> MediaArrangement {
        // First claimant wins when two blocks ask for the band.
        guard let index = blocks.firstIndex(where: {
            MediaLayout.resolve($0.mediaLayout).takesTheBand
        }) else { return .stacked }

        let hasCompany = blocks.count > 1
        switch MediaLayout.resolve(blocks[index].mediaLayout) {
        case .fill:
            // A literal fill with other blocks present would drop them; split keeps them on screen.
            return hasCompany ? .split(mediaIndex: index) : .fill(index: index)
        case .split:
            // A split box with nothing beside it is a half-width picture against dead air.
            return hasCompany ? .split(mediaIndex: index) : .fill(index: index)
        case .inline:
            return .stacked
        }
    }
}

// MARK: - Media band role

/// The role a media block plays in its band. Carried by the environment because the block that
/// honours it sits several `@ViewBuilder` hops below the view that decides the arrangement.
enum MediaBandRole {
    /// One block among others in the stack; the default.
    case inline
    /// The picture is the band. The action bar draws the caption, so the block must not.
    case fill
    /// The picture shares the band with a text column and fills its half.
    case split
}

private struct MediaBandRoleKey: EnvironmentKey {
    static let defaultValue: MediaBandRole = .inline
}

extension EnvironmentValues {
    var mediaBandRole: MediaBandRole {
        get { self[MediaBandRoleKey.self] }
        set { self[MediaBandRoleKey.self] = newValue }
    }
}
