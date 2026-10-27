//
//  ExpandableTileLayer.swift
//  dialog
//
//  Expand-in-place for a grid of tappable tiles: the tapped tile's detail fills the band the tiles
//  occupy, siblings hide, and Esc or a tap outside collapses it. Knows nothing about bento or any
//  detail chrome; the `detail` builder can return anything.
//

import SwiftUI

/// The spring every expand/collapse in this family uses, so tile surfaces animate identically.
enum ExpandInPlaceMotion {
    static let spring: Animation = .spring(response: 0.4, dampingFraction: 0.85)
}

extension View {
    /// Adds a tap gesture only when the tile has something to expand into.
    @ViewBuilder
    func tileTap(enabled: Bool, action: @escaping () -> Void) -> some View {
        if enabled {
            contentShape(Rectangle())
                .onTapGesture(perform: action)
        } else {
            self
        }
    }
}

/// `Tiles` is the caller's own tile layout, laid out in the same container that sizes the band;
/// `Detail` fills that band once a tile is expanded. Set `expandedId` from a tile's tap inside
/// `withAnimation(ExpandInPlaceMotion.spring)` so open and close share one feel.
struct ExpandableTileLayer<Tiles: View, Detail: View>: View {
    @Binding var expandedId: String?
    /// Builds the tile layout. `isHidden(id)` is true for every tile, including the tapped one,
    /// while a detail owns the band; the detail's header already shows the tile's identity.
    @ViewBuilder let tiles: (_ isHidden: @escaping (String) -> Bool) -> Tiles
    /// Builds the detail view for the expanded id. Invoked only while `expandedId` is non-nil.
    @ViewBuilder let detail: (_ id: String) -> Detail

    /// Esc needs a first responder; the layer takes focus itself because a chrome-less detail
    /// brings none. The 0.1s delay waits out the expand animation.
    @FocusState private var detailFocused: Bool

    var body: some View {
        ZStack {
            tiles { _ in expandedId != nil }
                .allowsHitTesting(expandedId == nil)

            if let id = expandedId {
                // Tap catcher under the detail: a tap anywhere else in the band collapses.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { collapse() }

                detail(id)
                    .transition(.opacity)
            }
        }
        .focusable(expandedId != nil)
        .focusEffectDisabled()
        .focused($detailFocused)
        .onChange(of: expandedId) { _, newValue in
            guard newValue != nil else {
                detailFocused = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { detailFocused = true }
        }
        .onKeyPress(.escape) {
            guard expandedId != nil else { return .ignored }
            collapse()
            return .handled
        }
        .onExitCommand { collapse() }
    }

    private func collapse() {
        guard expandedId != nil else { return }
        withAnimation(ExpandInPlaceMotion.spring) {
            expandedId = nil
        }
    }
}
