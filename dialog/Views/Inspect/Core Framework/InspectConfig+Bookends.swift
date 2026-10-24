//
//  InspectConfig+Bookends.swift
//  dialog
//
//  Bookend projection: the intro and outro screens as steps.
//

import Foundation
import SwiftUI

// MARK: - Bookend Projection

extension InspectConfig {

    /// Ids the bookend projection owns. A config that authors a step with either is rejected at decode.
    static let reservedIntroStepId = "_intro"
    static let reservedOutroStepId = "_outro"
    static var reservedBookendIds: Set<String> { [reservedIntroStepId, reservedOutroStepId] }

    /// The config's steps plus its projected bookends; read by step-engine hosts. `introSteps` stays as authored.
    var stepsWithBookends: [IntroStep]? {
        InspectConfig.projectBookends(into: introSteps,
                                      introScreen: introScreen,
                                      summaryScreen: summaryScreen)
    }

    /// One end of a flow, described so the projection treats intro and outro alike.
    private struct Bookend {
        let id: String
        let phase: String
        let screen: any Encodable
        /// The step already occupying this end, if any.
        let edge: ([IntroStep]) -> IntroStep?
        let insert: (inout [IntroStep], IntroStep) -> Void
    }

    private static func bookends(introScreen: PresetIntroScreen?,
                                 summaryScreen: PresetSummaryScreen?) -> [Bookend] {
        var slots: [Bookend] = []
        if let introScreen {
            slots.append(Bookend(id: reservedIntroStepId, phase: "intro", screen: introScreen,
                                 edge: { $0.first },
                                 insert: { $0.insert($1, at: 0) }))
        }
        if let summaryScreen {
            slots.append(Bookend(id: reservedOutroStepId, phase: "outro", screen: summaryScreen,
                                 edge: { $0.last },
                                 insert: { $0.append($1) }))
        }
        return slots
    }

    /// Projects root `introScreen`/`summaryScreen` into the step list (intro at index 0, outro last) without
    /// changing the keys, which presets 1–4 still read. Authored steps keep their order. A bookend is skipped,
    /// with a log line, when the flow already ends in that phase.
    static func projectBookends(into steps: [IntroStep]?,
                                introScreen: PresetIntroScreen?,
                                summaryScreen: PresetSummaryScreen?) -> [IntroStep]? {
        let slots = bookends(introScreen: introScreen, summaryScreen: summaryScreen)
        guard !slots.isEmpty else { return steps }

        var out = steps ?? []
        for bookend in slots {
            // Already projected: a no-op.
            guard !out.contains(where: { $0.id == bookend.id }) else { continue }

            // The flow already provides this end itself.
            if let edge = bookend.edge(out), edge.resolvedPhase == bookend.phase {
                writeLog("""
                    InspectConfig: '\(bookend.id)' not projected — the flow already \
                    \(bookend.phase == "intro" ? "opens" : "closes") with step '\(edge.id)'
                    """, logLevel: .info)
                continue
            }

            guard let step = synthesizeBookendStep(id: bookend.id, phase: bookend.phase,
                                                   from: bookend.screen) else { continue }
            bookend.insert(&out, step)
        }
        return out
    }

    /// Bookend `layout` values a step can render. A projected step (reserved id `_intro`/`_outro`) is routed by
    /// `Preset5.currentStepView` to `BookendScreenView`, which reads the root `introScreen`/`summaryScreen`
    /// keys, since the projected step cannot carry every ceremony field. An authored step with one of these
    /// names renders the plain column and gets an advisory via `silentDefaultAdvisories`. A value nothing
    /// renders still fails loudly below.
    static let stepRenderableBookendLayouts: Set<String> =
        ["centered", "overview", "welcome", "explainer", "dock", "receipt", "nextsteps"]

    /// Builds a step from a bookend screen by re-decoding its encoding, so it is as valid as an authored step.
    private static func synthesizeBookendStep(
        id: String, phase: String, from screen: any Encodable
    ) -> IntroStep? {
        guard let data = try? JSONEncoder().encode(screen),
              var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            writeLog("InspectConfig: could not project bookend '\(id)'", logLevel: .error)
            return nil
        }

        json["id"] = id
        json["phase"] = phase

        if let layout = json["layout"] as? String,
           !stepRenderableBookendLayouts.contains(layout) {
            writeLog("""
                InspectConfig: bookend '\(id)' asks for layout '\(layout)', which no \
                path renders — the projected step will show the plain column. Known \
                layouts: \(stepRenderableBookendLayouts.sorted().joined(separator: ", ")).
                """, logLevel: .default)
        }
        // Bookends call the primary button `buttonText`; steps call it `continueButtonText`. Other names match,
        // and unknown ones are ignored by the decoder.
        if let buttonText = json.removeValue(forKey: "buttonText") {
            json["continueButtonText"] = buttonText
        }

        guard let stepData = try? JSONSerialization.data(withJSONObject: json),
              let step = try? JSONDecoder().decode(IntroStep.self, from: stepData) else {
            writeLog("InspectConfig: bookend '\(id)' did not decode as a step", logLevel: .error)
            return nil
        }

        var advisories: [String] = []
        return canonicalizeStep(step, advisories: &advisories)
    }
}
