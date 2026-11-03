//
//  NavigationDialogView.swift
//  dialog
//
//  Sidebar presentation of a cards workflow (`"cardstyle": "navigation"`).
//  Each card is a sidebar item and is rendered in the detail pane as a standard dialog.
//

import SwiftUI
import SwiftyJSON

struct NavigationDialogView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @ObservedObject var cards: CardState = cardState

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Sidebar selection. Writes route through the page-leave logic rather than
    /// changing the index directly.
    private var selection: Binding<Int?> {
        Binding(
            get: { observedData.currentCardIndex },
            set: { newValue in
                guard let newValue else { return }
                observedData.navigateToPage(newValue)
            }
        )
    }

    /// Default sidebar width, roughly matching System Settings.
    static let defaultSidebarWidth: CGFloat = 260

    /// Fixed sidebar width: the top-level `sidebarwidth` if set, otherwise the default.
    private var sidebarWidth: CGFloat {
        guard let configured = cards.globalConfiguration["sidebarwidth"].double, configured > 0 else {
            return Self.defaultSidebarWidth
        }
        return CGFloat(configured)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                NavigationSidebarHeader(configuration: cards.globalConfiguration)
                List(selection: selection) {
                    ForEach(cards.sections) { section in
                        if let title = section.title {
                            Section {
                                sidebarRows(for: section)
                            } header: {
                                NavigationSectionHeader(
                                    title: title,
                                    hasIssue: section.cardIndices.contains { cards.visibleIssue(for: $0) != nil }
                                )
                            }
                        } else {
                            sidebarRows(for: section)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(sidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            ContentView(observedDialogContent: observedData)
        }
        .onChange(of: columnVisibility) { _, newValue in
            // Pages are only reachable from the sidebar, so it can't be collapsed
            if newValue != .all {
                columnVisibility = .all
            }
        }
    }

    @ViewBuilder
    private func sidebarRows(for section: CardSection) -> some View {
        ForEach(section.cardIndices, id: \.self) { index in
            NavigationSidebarRow(
                title: cards.cards[index].sidebarTitle ?? "Page \(index + 1)",
                icon: cards.cards[index].sidebarIcon,
                issue: cards.visibleIssue(for: index)
            )
            .tag(index)
        }
    }
}

/// Top-level `title` and `icon` shown above the page list.
struct NavigationSidebarHeader: View {
    let configuration: JSON

    private var title: String? {
        guard let value = configuration["title"].string, !value.isEmpty, value != "none" else { return nil }
        return value
    }

    private var icon: String? {
        guard let value = configuration["icon"].string, !value.isEmpty, value != "none" else { return nil }
        return value
    }

    var body: some View {
        if title != nil || icon != nil {
            HStack(spacing: 10) {
                if let icon {
                    IconView(image: icon, sfPaddingEnabled: false)
                        .frame(width: 32, height: 32)
                }
                if let title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct NavigationSectionHeader: View {
    let title: String
    let hasIssue: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if hasIssue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Contains incomplete pages".localized)
            }
        }
    }
}

struct NavigationSidebarRow: View {
    let title: String
    let icon: String?
    let issue: String?

    var body: some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                if let icon {
                    IconView(image: icon, sfPaddingEnabled: false)
                        .frame(width: 18, height: 18)
                }
            }
            Spacer(minLength: 0)
            if let issue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(issue)
                    .accessibilityLabel("Incomplete".localized)
            }
        }
    }
}
