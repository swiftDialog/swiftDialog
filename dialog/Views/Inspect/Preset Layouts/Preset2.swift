//
//  Preset2.swift
//  dialog
//
//  A placeholder for the Preset 2 view, so every name the routing shell dispatches to resolves.
//

import SwiftUI

struct Preset2View: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        Text("Preset 2 view: assembled in a later commit of this series")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
