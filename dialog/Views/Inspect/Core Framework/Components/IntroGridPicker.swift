//
//  IntroGridPicker.swift
//  dialog
//
//  Selectable grid picker for intro-style steps.
//

import SwiftUI

// MARK: - Grid Picker Component

/// Grid picker for wallpaper/theme selection screens.
struct IntroGridPicker: View {
    let items: [IntroGridItem]
    let columns: Int
    let selectionMode: String  // "single" | "multiple" | "none"
    @Binding var selectedIds: Set<String>
    let accentColor: Color

    init(
        items: [IntroGridItem],
        columns: Int = 3,
        selectionMode: String = "single",
        selectedIds: Binding<Set<String>>,
        accentColor: Color = .accentColor
    ) {
        self.items = items
        self.columns = columns
        self.selectionMode = selectionMode
        self._selectedIds = selectedIds
        self.accentColor = accentColor
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(items) { item in
                IntroGridCell(
                    item: item,
                    isSelected: selectedIds.contains(item.id),
                    accentColor: accentColor
                ) {
                    toggleSelection(item.id)
                }
            }
        }
        .padding()
    }

    private func toggleSelection(_ id: String) {
        switch selectionMode.lowercased() {
        case "single":
            selectedIds = [id]
        case "multiple":
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        default: // "none"
            break
        }
    }
}

/// Grid item model for `IntroGridPicker`.
struct IntroGridItem: Identifiable, Codable {
    let id: String
    let imagePath: String?
    let sfSymbol: String?
    let title: String?
    let subtitle: String?
    let value: String?
}

/// One cell in `IntroGridPicker`.
struct IntroGridCell: View {
    @Environment(\.palette) private var palette

    let item: IntroGridItem
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                imageContent
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let title = item.title {
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                }

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 3)
            )
            .overlay(
                isSelected ?
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accentColor)
                        .font(.title2)
                        .padding(8)
                    : nil,
                alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let imagePath = item.imagePath, let nsImage = InspectImageCache.shared.image(atPath: imagePath) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else if let sfSymbol = item.sfSymbol {
            Image(systemName: sfSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(accentColor)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(accentColor.opacity(0.1))
        } else {
            palette.text.opacity(0.2)
        }
    }
}


// MARK: - Grid picker as a content block

/// `type: "grid-picker"`: the grid picker as a content block, honouring `gridColumns`.
/// Selection lives in `userValues`; the wire carries each item's `value` (default: its id), while the
/// picker selects by id, so the two are mapped at the boundary.
struct GuidanceGridPickerBlock<Context: UserInputContext & ObservableObject>: View {
    let items: [InspectConfig.GridItemConfig]
    let columns: Int
    let selectionMode: String
    let selectionKey: String
    let accentColor: Color
    @ObservedObject var inspectState: Context

    @State private var selectedIds: Set<String> = []
    @State private var didRestore = false

    /// id → wire value; `value` defaults to the id.
    private func wireValue(for id: String) -> String? {
        items.first { $0.id == id }.map { $0.value ?? $0.id }
    }

    var body: some View {
        IntroGridPicker(
            items: items.map {
                IntroGridItem(
                    id: $0.id,
                    imagePath: $0.imagePath,
                    sfSymbol: $0.sfSymbol,
                    title: $0.title,
                    // `description` beats `subtitle`, as in the step arms.
                    subtitle: $0.description ?? $0.subtitle,
                    value: $0.value ?? $0.id
                )
            },
            columns: columns,
            selectionMode: selectionMode,
            selectedIds: Binding(
                get: { selectedIds },
                set: { newValue in
                    selectedIds = newValue
                    record(newValue)
                }
            ),
            accentColor: accentColor
        )
        .onAppear {
            guard !didRestore else { return }
            didRestore = true
            // Maps stored wire values back to ids; values with no matching item are dropped.
            guard let stored = inspectState.userValues[selectionKey], !stored.isEmpty else { return }
            let wanted = Set(stored.components(separatedBy: ",").filter { !$0.isEmpty })
            selectedIds = Set(items.filter { wanted.contains($0.value ?? $0.id) }.map(\.id))
        }
    }

    /// Same emission rule as `OptionPicker.recordSelection`.
    private func record(_ ids: Set<String>) {
        let values = ids.compactMap(wireValue(for:)).sorted()
        let joined = values.joined(separator: ",")
        guard SelectionEmission.shouldEmit(newValue: joined,
                                           recorded: inspectState.userValues[selectionKey],
                                           trigger: .committed) else { return }
        inspectState.userValues[selectionKey] = joined
        inspectState.writeToInteractionLog("select:\(selectionKey):\(joined)")
        DialogNotifications.postSelection(key: selectionKey, values: values)
    }
}
