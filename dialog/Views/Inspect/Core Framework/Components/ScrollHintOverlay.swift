//
//  ScrollHintOverlay.swift
//  dialog
//
//  Scroll affordance overlay and its preference/environment plumbing.
//

import SwiftUI

// MARK: - Scroll Hint Overlay

/// Tracks content height inside a ScrollView and reports whether the content overflows.
/// Use with `ScrollHintOverlay` to show a bottom fade + chevron cue.
struct ScrollContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A bottom fade and chevron shown while scrollable content overflows; hides near the bottom.
/// Overlay it on a ZStack around the ScrollView.
struct ScrollHintOverlay: View {
    let containerHeight: CGFloat
    let contentHeight: CGFloat
    let scrollOffset: CGFloat

    private var contentOverflows: Bool {
        contentHeight > containerHeight + 10
    }

    private var isNearBottom: Bool {
        // scrollOffset is negative as you scroll down.
        let scrolled = -scrollOffset
        return scrolled + containerHeight >= contentHeight - 20
    }

    private var shouldShow: Bool {
        contentOverflows && !isNearBottom
    }

    var body: some View {
        if shouldShow {
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color(NSColor.windowBackgroundColor).opacity(0),
                            Color(NSColor.windowBackgroundColor).opacity(0.85),
                            Color(NSColor.windowBackgroundColor)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 48)

                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.bottom, 6)
                }
            }
            .allowsHitTesting(false)
            // Decoration only; kept out of the accessibility tree.
            .accessibilityHidden(true)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: shouldShow)
        }
    }
}

/// Preference key for tracking vertical scroll offset within a named coordinate space.
struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Scroll tracking for a ScrollView's inner content.
extension View {
    /// Reports content height and scroll offset. Place on the VStack inside a ScrollView and wire
    /// the values into a `ScrollHintOverlay` (see AnchoredStepContent, Preset6+StepContent).
    func trackScrollForHint(coordinateSpace: String = "scrollHint") -> some View {
        self
            .background(GeometryReader { innerGeo in
                Color.clear
                    .preference(key: ScrollContentHeightKey.self, value: innerGeo.size.height)
            })
            .background(GeometryReader { innerGeo in
                Color.clear
                    .preference(key: ScrollOffsetKey.self,
                                value: innerGeo.frame(in: .named(coordinateSpace)).minY)
            })
    }

}
