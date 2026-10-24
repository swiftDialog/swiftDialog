//
//  Preset1.swift
//  dialog
//
//  A placeholder for the Preset 1 view, so every name the routing shell dispatches to resolves.
//

import SwiftUI

struct Preset1View: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        Text("Preset 1 view: assembled in a later commit of this series")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
