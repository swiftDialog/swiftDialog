//
//  PayloadAlignment.swift
//  Dialog
//
//  Where payload content sits in the band it is given.
//

import SwiftUI

/// Vertical placement of a step's payload: top-aligned so content follows its heading, except a
/// payload that is one self-contained media object, which centres because the object is the
/// band's content. Pure so it can be tested without rendering.
enum PayloadAlignment {

    /// Block types that can be the payload rather than sit in one.
    private static let selfContained: Set<String> = [
        "image", "image-carousel", "video", "portal-webview"
    ]

    /// `.topLeading` for ordinary content, `.leading` for a lone self-contained object; in a
    /// `maxHeight: .infinity` frame the two differ only on the vertical axis. The payload must be
    /// exactly one block, or a single image anywhere on a step would centre everything.
    static func alignment(for blocks: [InspectConfig.GuidanceContent]) -> Alignment {
        guard blocks.count == 1, let only = blocks.first,
              selfContained.contains(only.type) else {
            return .topLeading
        }
        return .leading
    }
}
