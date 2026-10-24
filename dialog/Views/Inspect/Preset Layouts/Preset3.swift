//
//  Preset3.swift
//  dialog
//
//  A placeholder for the Preset 3 view, so every name the routing shell dispatches to resolves.
//

import SwiftUI

struct Preset3View: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        Text("Preset 3 view: assembled in a later commit of this series")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
