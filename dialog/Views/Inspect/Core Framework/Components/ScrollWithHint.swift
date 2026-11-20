//
//  ScrollWithHint.swift
//  dialog
//
//  A vertical ScrollView paired with `ScrollHintOverlay`, the bottom fade that says there is more
//  below. Content that fits draws no cue.
//

import SwiftUI

/// A container rather than a modifier: the overlay needs the container's own height as well as
/// the scroll view's content size and offset.
struct ScrollWithHint<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical) {
                    content()
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height
                } action: { _, newHeight in
                    contentHeight = newHeight
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newOffsetY in
                    // contentOffset grows downward; the overlay's formula expects the opposite sign.
                    scrollOffset = -newOffsetY
                }

                ScrollHintOverlay(containerHeight: geo.size.height,
                                  contentHeight: contentHeight,
                                  scrollOffset: scrollOffset)
                    // Decoration only; clicks must reach the row beneath.
                    .allowsHitTesting(false)
            }
        }
    }
}
