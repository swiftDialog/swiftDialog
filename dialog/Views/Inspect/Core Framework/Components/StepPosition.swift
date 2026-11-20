//
//  StepPosition.swift
//  dialog
//
//  Where a step sits in its series. Derived by the flow from the step index, never authored
//  (the wire's `stepType: "intro"` means phase intro and stays untouched), and injected through
//  the environment. Only chrome reads it: footer buttons, step counter, backdrop. A payload
//  never branches on position; a payload that needs to is two screens.
//

import SwiftUI

/// Where a step sits in its series. `.main` is the default because it asserts nothing: a
/// component that has not been told its position must not act on one.
enum StepPosition: String, Equatable {
    case intro
    case main
    case outro

    /// Derives the position from an index within a flat series. A single-step series resolves to
    /// `.intro` so Back stays hidden; `Done` versus `Continue` remains the caller's decision.
    /// Preset 6 derives per phase on its own and does not use this.
    init(index: Int, count: Int) {
        if count <= 1 {
            self = .intro
        } else if index <= 0 {
            self = .intro
        } else if index >= count - 1 {
            self = .outro
        } else {
            self = .main
        }
    }
}

private struct StepPositionKey: EnvironmentKey {
    static let defaultValue: StepPosition = .main
}

extension EnvironmentValues {
    /// Injected once by the flow at its step-dispatch root. Read by chrome, never by a payload.
    var stepPosition: StepPosition {
        get { self[StepPositionKey.self] }
        set { self[StepPositionKey.self] = newValue }
    }
}
