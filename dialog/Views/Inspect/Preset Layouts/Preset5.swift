//
//  Preset5.swift
//  dialog
//
//  A placeholder for the Preset 5 view (the step engine), so every name the routing shell
//  dispatches to resolves.
//

import SwiftUI

// MARK: - Type Aliases for Shared Enums

typealias CompletionResult = InspectCompletionResult

typealias OverrideLevel = InspectOverrideLevel

struct Preset5View: View {

    @ObservedObject var inspectState: InspectState

    var body: some View {
        Text("Preset 5 view: assembled in a later commit of this series")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
