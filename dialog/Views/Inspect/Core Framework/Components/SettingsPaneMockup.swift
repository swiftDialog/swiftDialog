//
//  SettingsPaneMockup.swift
//  dialog
//
//  A drawn specimen of the System Settings pane a step sends the user to, with the one authored row
//  highlighted. Eleven panes; rows have the right shape (toggle, value, swatch, button), not a replica.

import SwiftUI

/// Which pane, and the shape of its rows: switches, values or swatches.
enum SettingsPaneKind: String, CaseIterable {
    case users = "users"
    case network = "network"
    case vpn = "vpn"
    case displays = "displays"
    case privacy = "privacy"
    case accessibility = "accessibility"
    case softwareUpdate = "software-update"
    case wifi = "wifi"
    case appearance = "appearance"
    case desktopDock = "desktop-dock"
    case screenRecording = "screen-recording"

    /// Accepts likely spellings, so "Privacy & Security" and "privacy" reach the same pane.
    init?(authored: String) {
        let k = authored.lowercased()
            .replacingOccurrences(of: "&", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        switch k {
        case "users", "users and groups", "users  groups", "accounts", "users and accounts":
            self = .users
        case "network": self = .network
        case "vpn": self = .vpn
        case "displays", "display": self = .displays
        case "privacy", "security", "privacy  security", "privacy and security": self = .privacy
        case "accessibility": self = .accessibility
        case "software update", "software-update", "updates": self = .softwareUpdate
        case "wifi", "wi fi", "wi-fi": self = .wifi
        case "appearance": self = .appearance
        case "desktop  dock", "desktop and dock", "desktop-dock", "dock": self = .desktopDock
        case "screen recording", "screen-recording", "screen  system recording",
             "screen and system recording", "screen  system audio recording",
             "screen and system audio recording": self = .screenRecording
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .users: return "Users & Groups"
        case .network: return "Network"
        case .vpn: return "VPN"
        case .displays: return "Displays"
        case .privacy: return "Privacy & Security"
        case .accessibility: return "Accessibility"
        case .softwareUpdate: return "Software Update"
        case .wifi: return "Wi-Fi"
        case .appearance: return "Appearance"
        case .desktopDock: return "Desktop & Dock"
        case .screenRecording: return "Screen & System Audio Recording"
        }
    }

    var symbol: String {
        switch self {
        case .users: return "person.2.fill"
        case .network: return "network"
        case .vpn: return "lock.shield.fill"
        case .displays: return "display"
        case .privacy: return "hand.raised.fill"
        case .accessibility: return "figure.wave"
        case .softwareUpdate: return "gear.badge"
        case .wifi: return "wifi"
        case .appearance: return "paintbrush.fill"
        case .desktopDock: return "menubar.dock.rectangle"
        case .screenRecording: return "rectangle.inset.filled.badge.record"
        }
    }

    /// How a row reads on this pane. `action` draws a button (e.g. a VPN's Connect) rather than a done-state label.
    enum RowShape { case toggle, value, swatch, action(String) }

    var rowShape: RowShape {
        switch self {
        case .privacy, .accessibility, .screenRecording: return .toggle
        case .vpn, .network: return .action("Connect")
        case .wifi: return .action("Join")
        case .appearance: return .swatch
        default: return .value
        }
    }

    /// Plausible neighbour rows so the list does not read as one item; never this Mac's real state.
    var defaultRows: [String] {
        switch self {
        case .users: return ["Standard User", "Guest User", "Login Options"]
        case .network: return ["Wi-Fi", "Ethernet", "Thunderbolt Bridge"]
        case .vpn: return ["Corporate VPN", "Split Tunnel"]
        case .displays: return ["Built-in Display", "Studio Display"]
        case .privacy: return ["Location Services", "Files and Folders", "Full Disk Access"]
        case .accessibility: return ["VoiceOver", "Zoom", "Display"]
        case .softwareUpdate: return ["Automatic updates", "Security responses"]
        case .wifi: return ["Corporate", "Corporate-Guest", "Other…"]
        case .appearance: return ["Light", "Dark", "Auto"]
        case .desktopDock: return ["Position on screen", "Minimise windows", "Stage Manager"]
        case .screenRecording: return ["Microsoft Teams", "Zoom"]
        }
    }

    /// A few sidebar neighbours.
    var siblings: [SettingsPaneKind] {
        let all: [SettingsPaneKind] = [.wifi, .network, .vpn, .displays, .privacy,
                                       .accessibility, .softwareUpdate, .users]
        var out = all.filter { $0 != self }
        out.insert(self, at: min(2, out.count))
        return Array(out.prefix(6))
    }
}

struct SettingsPaneMockup: View {
    let pane: SettingsPaneKind
    /// The one highlighted row (a VPN, an allow-listed app, whatever asked). Prepended when not
    /// already among the pane's rows.
    var highlighted: String?
    /// Rows to draw in place of the pane's defaults.
    var rows: [String]?
    /// A line under the list, e.g. "You will be asked once."
    var footnote: String?
    let accent: Color

    @Environment(\.palette) private var palette

    private var resolvedRows: [String] {
        var list = rows?.isEmpty == false ? rows! : pane.defaultRows
        if let highlighted, !highlighted.isEmpty,
           !list.contains(where: { $0.compare(highlighted, options: .caseInsensitive) == .orderedSame }) {
            list.insert(highlighted, at: 0)
        }
        return list
    }

    private func isHighlighted(_ row: String) -> Bool {
        guard let highlighted, !highlighted.isEmpty else { return false }
        return row.compare(highlighted, options: .caseInsensitive) == .orderedSame
    }

    /// Below this width the sidebar is dropped, keeping the header and highlighted row. Sits between
    /// plain-branded's 500 column (drops it) and plain-simple's 560 card (keeps it).
    static let sidebarNeedsWidth: CGFloat = 520

    /// The specimen caps at this width and centres, so it still looks like a window; narrower hosts fill.
    static let naturalWidth: CGFloat = 560

    var body: some View {
        GeometryReader { geo in
            let drawn = min(geo.size.width, Self.naturalWidth)
            HStack(spacing: 0) {
                if drawn >= Self.sidebarNeedsWidth {
                    sidebar
                    Divider()
                }
                content
            }
            .frame(width: drawn)
            // Window chrome inside the cap, so the ground and border do not span the whole column.
            .background(palette.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            )
            // Centred, so a wide column pads rather than stretches.
            .frame(maxWidth: .infinity)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(pane.siblings, id: \.self) { item in
                HStack(spacing: 7) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item == pane ? .white : palette.textMuted)
                        .frame(width: 16, height: 16)
                        .background(RoundedRectangle(cornerRadius: 4).fill(item == pane ? accent : .clear))
                    Text(item.title)
                        .font(.system(size: 11, weight: item == pane ? .semibold : .regular))
                        .foregroundStyle(item == pane ? palette.text : palette.textMuted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(item == pane ? palette.text.opacity(0.07) : .clear))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: 150, alignment: .topLeading)
        .background(palette.text.opacity(0.03))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pane.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.text)

            VStack(spacing: 0) {
                ForEach(Array(resolvedRows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().padding(.leading, 12) }
                    rowView(row)
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.cardSurface))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.hairline, lineWidth: 1))

            if let footnote, !footnote.isEmpty {
                Text(footnote)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func rowView(_ row: String) -> some View {
        let hot = isHighlighted(row)
        HStack(spacing: 8) {
            Text(row)
                .font(.system(size: 11.5, weight: hot ? .semibold : .regular))
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            switch pane.rowShape {
            case .toggle:
                // On for the highlighted row: the end state the step asks the user to reach.
                Capsule()
                    .fill(hot ? accent : palette.text.opacity(0.18))
                    .frame(width: 26, height: 15)
                    .overlay(alignment: hot ? .trailing : .leading) {
                        Circle().fill(.white)
                            .frame(width: 11, height: 11)
                            .padding(.horizontal, 2)
                            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    }
            case .action(let label):
                // Filled only on the highlighted row, so the specimen points at one control.
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hot ? .white : palette.text)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .fill(hot ? accent : palette.text.opacity(0.08)))
            case .value:
                Text(hot ? "On" : "—")
                    .font(.system(size: 10.5))
                    .foregroundStyle(hot ? accent : palette.textFaint)
            case .swatch:
                RoundedRectangle(cornerRadius: 3)
                    .fill(hot ? accent : palette.text.opacity(0.18))
                    .frame(width: 18, height: 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        // A faint wash and leading bar mark the row without making the list look selectable.
        .background(hot ? accent.opacity(0.09) : .clear)
        .overlay(alignment: .leading) {
            if hot { Rectangle().fill(accent).frame(width: 2.5) }
        }
    }
}
