//
//  Preset5+Splash.swift — wiring for the splash / chooser shell.
//
//  The shell draws; this resolves artwork and words from the step and config and passes them in.
//

import SwiftUI

extension Preset5View {

    @ViewBuilder
    func splashChooserStepView(step: InspectConfig.IntroStep) -> some View {
        SplashChooserShell(
            // The splash seats the mark itself, so a corner-only config still gets its mark here.
            markPath: BrandArtwork.resolve(inspectState.config?.logoConfig,
                                           isDark: true, surface: .photograph),
            markBasePath: inspectState.uiConfiguration.iconBasePath,
            title: step.title,
            subtitle: step.subtitle,
            doors: SplashDoors.titles(for: step),
            onDoor: { index in
                // Any door reports the pick: a user who never opened the picker chose the default.
                recordSplashPickIfUnset(step: step)
                if index == SplashDoors.deferIndex(for: step) {
                    presetCleanExit(state: inspectState, triggerFilePath: triggerFilePath,
                                    label: "Preset5Splash", message: "deferred from the splash chooser",
                                    exitCode: 2)
                } else {
                    goToNextStep()
                }
            },
            footnote: step.footerNote,
            environments: (step.environments ?? []).map {
                SplashEnvironment(id: $0.id, title: $0.title, subtitle: $0.subtitle)
            },
            environmentLabel: step.environmentLabel,
            onSelectEnvironment: { index in
                guard let environments = step.environments, environments.indices.contains(index) else { return }
                inspectState.userValues[SplashPick.key(for: step)] = environments[index].value
            },
            learnMoreText: step.learnMoreText,
            learnMoreURL: step.learnMoreURL.flatMap(IntroMediaURL.resolve),
            accent: branding.primaryColor,
            // Same pools as the screens behind it, so the cross-fade lands on identical ground.
            groundPools: SplashPick.groundPools(config: inspectState.config)
        )
    }

    /// Records the first destination when nothing was picked; only a chooser of two or more reports.
    func recordSplashPickIfUnset(step: InspectConfig.IntroStep) {
        guard let value = SplashPick.defaultValue(for: step) else { return }
        let key = SplashPick.key(for: step)
        if inspectState.userValues[key] == nil { inspectState.userValues[key] = value }
    }
}

/// Which doors the splash draws and which defers. Primary first; a door with no text is not drawn;
/// the last of two or more defers (exit 2). `showBackButton: false` removes the defer door, and
/// no other door becomes the deferral by being last.
enum SplashDoors {
    static func titles(for step: InspectConfig.IntroStep) -> [String] {
        let back = step.showBackButton == false ? nil : step.backButtonText
        return [step.continueButtonText, step.secondaryButtonText, back]
            .compactMap { $0 }.filter { !$0.isEmpty }
    }

    static func deferIndex(for step: InspectConfig.IntroStep) -> Int? {
        guard step.showBackButton != false else { return nil }
        let count = titles(for: step).count
        return count > 1 ? count - 1 : nil
    }
}
