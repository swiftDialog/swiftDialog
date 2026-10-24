//
//  Preset4.swift
//  dialog
//
//  A placeholder for the Preset 4 view, so every name the routing shell dispatches to resolves.
//

import SwiftUI

struct Preset4View: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        Text("Preset 4 view: assembled in a later commit of this series")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preset4 Wrapper

struct Preset4Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset4View(inspectState: coordinator)
    }
}
