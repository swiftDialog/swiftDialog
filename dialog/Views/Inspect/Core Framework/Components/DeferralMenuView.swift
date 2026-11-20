//
//  DeferralMenuView.swift
//  dialog
//
//  The shared "remind me later" menu, used by Preset 4's toast and the Preset 5/6 footers. A
//  selection writes the result file and exits through the deferral path (exit code 10).
//

import SwiftUI

/// A dropdown of deferral durations, from the config or the launching environment.
struct DeferralMenuView: View {
    let config: InspectConfig?
    let accentColor: Color
    let buttonText: String?
    let style: DeferralMenuStyle

    enum DeferralMenuStyle {
        case bordered    // phase and card footers
        case compact     // Preset 4 toast
    }

    init(
        config: InspectConfig?,
        accentColor: Color = .accentColor,
        buttonText: String? = nil,
        style: DeferralMenuStyle = .bordered
    ) {
        self.config = config
        self.accentColor = accentColor
        self.buttonText = buttonText
        self.style = style
    }

    private var label: String {
        buttonText ?? config?.deferralConfig?.buttonText ?? "Not Now"
    }

    private var options: [InspectConfig.DeferOption] {
        resolvedDeferralOptions(config: config)
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.duration) { option in
                Button(option.label ?? deferralLabel(for: option.duration)) {
                    performDeferral(duration: option.duration, config: config)
                }
            }
        } label: {
            Text(label)
                .font(style == .compact ? .system(size: 12) : .body)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(style == .bordered ? accentColor : nil)
    }
}
