//
//  Preset6.swift
//  dialog
//
//  Preset 6: sidebar navigation with a content panel and footer; intro/outro use BookendScreenView.
//  Extensions in Preset6+*.swift add commands, processing, persistence and card/rail chromes.
//

import SwiftUI

// MARK: - Preset6 State Definition

struct Preset6State: InspectPersistableState {
    let completedSteps: Set<String>
    let currentStep: Int
    let guidanceFormInputs: [String: GuidanceFormInputState]
    let timestamp: Date
}

struct Preset6View: View {
    @ObservedObject var inspectState: InspectState

    var body: some View {
        Text("Preset 6 view: assembled in a later commit of this series")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Preset6 Wrapper

struct Preset6Wrapper: View {
    @ObservedObject var coordinator: InspectState

    var body: some View {
        Preset6View(inspectState: coordinator)
    }
}
