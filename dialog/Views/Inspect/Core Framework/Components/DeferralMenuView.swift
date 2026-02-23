//
//  DeferralMenuView.swift
//  dialog
//
//  Shared deferral menu component for user-initiated "remind me later" actions.
//  Integrates with ignitecli's deferral system (env vars, exit code 10, result file).
//  Reusable across Preset4, Preset5, and future presets.
//

import SwiftUI

/// A dropdown menu presenting deferral duration options.
/// Reads options from config or ignitecli env vars, writes result file on selection, exits.
struct DeferralMenuView: View {
    let config: InspectConfig?
    let accentColor: Color
    let buttonText: String?
    let style: DeferralMenuStyle

    enum DeferralMenuStyle {
        case bordered    // Standard bordered button (Preset5 footer)
        case compact     // Compact borderless (Preset4 toast)
    }

    init(
        config: InspectConfig?,
        accentColor: Color = .blue,
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
