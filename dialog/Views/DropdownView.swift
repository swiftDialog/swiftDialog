//
//  DropdownView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 2/6/21.
//

import Foundation
import SwiftUI
import Combine


struct DropdownView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var selectedOption: [String]

    var fieldwidth: CGFloat = 0

    var dropdownCount = 0

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        if !observedDialogContent.args.hideIcon.present {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue()
        } else {
            fieldwidth = observedDialogContent.args.windowWidth.value.floatValue() - observedDialogContent.args.iconSize.value.floatValue()
        }

        var defaultOptions: [String] = []
        for index in 0..<userInputState.dropdownItems.count {
            defaultOptions.append(userInputState.dropdownItems[index].defaultValue)
            if userInputState.dropdownItems[index].style != "radio" {
                dropdownCount+=1
            }
            for subIndex in 0..<userInputState.dropdownItems[index].values.count {
                let selectValue = userInputState.dropdownItems[index].values[subIndex]
                if selectValue.hasPrefix("---") && !selectValue.hasSuffix("<") {
                    // We need to modify each `---` entry so it is unique and doesn't cause errors when building the menu
                    userInputState.dropdownItems[index].values[subIndex].append(String(repeating: "-", count: subIndex).appending("<"))
                }
            }
        }
        _selectedOption = State(initialValue: defaultOptions)

        if dropdownCount > 0 {
            writeLog("Displaying select list")
        }
    }

    var body: some View {
        if observedData.args.dropdownValues.present && dropdownCount > 0 {
            VStack {
                ForEach(0..<userInputState.dropdownItems.count, id: \.self) {index in
                    if userInputState.dropdownItems[index].style != "radio" {
                        HStack {
                            // we could print the title as part of the picker control but then we don't get easy access to swiftui text formatting
                            // so we print it seperatly and use a blank value in the picker
                            HStack {
                                Text(userInputState.dropdownItems[index].title + (userInputState.dropdownItems[index].required ? " *":""))
                                    .frame(idealWidth: fieldwidth*0.20, alignment: .leading)
                                Spacer()
                            }
                            if ["searchable", "multiselect"].contains(userInputState.dropdownItems[index].style) {
                                SearchablePicker(
                                    title: "",
                                    allItems: userInputState.dropdownItems[index].values,
                                    selection: $selectedOption[index],
                                    allowMultiSelect: userInputState.dropdownItems[index].style == "multiselect",
                                    idealWidth: fieldwidth*0.50
                                )
                                    .onChange(of: selectedOption[index]) { _, selectedOption in
                                        userInputState.dropdownItems[index].selectedValue = selectedOption
                                    }
                                    .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(userInputState.dropdownItems[index].requiredfieldHighlight, lineWidth: 2)
                                        .animation(
                                            .easeIn(duration: 0.2).repeatCount(3, autoreverses: true),
                                            value: observedData.showSheet
                                        )
                                    )
                            } else {
                                Picker("", selection: $selectedOption[index]) {
                                    if userInputState.dropdownItems[index].defaultValue.isEmpty {
                                        // prevents "Picker: the selection "" is invalid and does not have an associated tag" errors on stdout
                                        // this does mean we are creating a blank selection but it will still be index -1
                                        // previous indexing schemes (first entry being index 0 etc) should still apply.
                                        Text("").tag("")
                                    }
                                    ForEach(userInputState.dropdownItems[index].values, id: \.self) {
                                        if $0.hasPrefix("---") {
                                            Divider()
                                        } else {
                                            Text($0).tag($0)
                                                .font(.system(size: observedData.appProperties.labelFontSize))
                                        }
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: selectedOption[index]) { _, selectedOption in
                                    userInputState.dropdownItems[index].selectedValue = selectedOption
                                }
                                .frame(idealWidth: fieldwidth*0.50, maxWidth: 350, alignment: .trailing)
                                .buttonSizeFit()
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(userInputState.dropdownItems[index].requiredfieldHighlight, lineWidth: 2)
                                    .animation(
                                        .easeIn(duration: 0.2).repeatCount(3, autoreverses: true),
                                        value: observedData.showSheet
                                    )
                                )
                            }
                        }
                    }
                }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .padding(10)
            .background(Color.background.opacity(0.5))
            .cornerRadius(8)

        }
    }
}

extension View {
    func buttonSizeFit() -> some View {
        if #available(macOS 26, *) {
            return buttonSizing(.flexible)
        } else {
            return self
        }
    }
}

// Implemtation of a searchable picker using TextField and popover with embedded scrollview

// MARK: - Searchable Picker (Single & Multi-Select)

struct SearchablePicker: View {
    let title: String
    let allItems: [String]
    @Binding var selection: String
    var allowMultiSelect: Bool = false
    var idealWidth: CGFloat = 200
    
    @State private var searchText = ""
    @State private var showPopup = false
    @FocusState private var isFocused: Bool
    @State private var selectedIndex: Int?
    @State private var didAppear = false
    
    // Parse CSV string into Set for multi-select
    private var selectedItems: Set<String> {
        guard allowMultiSelect else { return [] }
        return Set(selection.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
    
    // Items for display (includes dividers for visual separation)
    private var displayItems: [String] {
        if searchText.isEmpty {
            return allItems.filter { item in
                if item.hasPrefix("---") { return true }
                if allowMultiSelect { return !selectedItems.contains(item) }
                return true
            }
        }
        // When searching, exclude dividers
        return allItems.filter { item in
            guard !item.hasPrefix("---") else { return false }
            if allowMultiSelect && selectedItems.contains(item) { return false }
            return item.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Indices of selectable (non-divider) items for keyboard navigation
    private var selectableIndices: [Int] {
        displayItems.enumerated().compactMap { index, item in
            item.hasPrefix("---") ? nil : index
        }
    }
    
    private var borderColor: Color {
        isFocused ? Color.accentColor : Color(nsColor: .separatorColor)
    }
    
    var body: some View {
        Group {
            if allowMultiSelect {
                multiSelectBody
            } else {
                singleSelectBody
            }
        }
    }
    
    // MARK: - Single Select Body
    
    private var singleSelectBody: some View {
        HStack(spacing: 0) {
            TextField(title, text: $searchText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: searchText) {
                    // Only show popup when actually typing (not on initial load)
                    if didAppear {
                        showPopup = true
                        selectedIndex = selectableIndices.first
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        // Hide popup when focus leaves
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if !isFocused {
                                showPopup = false
                            }
                        }
                    }
                }
                .onAppear {
                    searchText = selection
                    showPopup = false
                    // Delay setting didAppear to prevent onChange triggering on initial value
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        didAppear = true
                    }
                }
                .onKeyPress(.downArrow) {
                    if !showPopup {
                        showPopup = true
                        selectedIndex = selectableIndices.first
                    } else {
                        moveSelection(1)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if showPopup {
                        moveSelection(-1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.return) {
                    if showPopup, let index = selectedIndex, index < displayItems.count {
                        let item = displayItems[index]
                        if !item.hasPrefix("---") {
                            select(item)
                            return .handled
                        }
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    if showPopup {
                        showPopup = false
                        return .handled
                    }
                    return .ignored
                }
            
            // Chevron button
            Button {
                isFocused = true
                showPopup.toggle()
                if showPopup {
                    selectedIndex = selectableIndices.first
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
        )
        .popover(isPresented: $showPopup, arrowEdge: .bottom) {
            dropdownContent
        }
    }
    
    // MARK: - Multi Select Body
    
    private var multiSelectBody: some View {
        HStack(spacing: 0) {
            FlowLayout(spacing: 4) {
                // Display selected tags
                ForEach(Array(selectedItems).sorted(), id: \.self) { item in
                    TagView(text: item) {
                        removeSelection(item)
                    }
                }
                
                // Search field with backspace handling
                BackspaceDetectingTextField(
                    placeholder: selectedItems.isEmpty ? title : "",
                    text: $searchText,
                    onBackspaceWhenEmpty: {
                        if let last = selectedItems.sorted().last {
                            removeSelection(last)
                        }
                    }
                )
                .focused($isFocused)
                .frame(minWidth: 60)
                .onChange(of: searchText) {
                    if didAppear {
                        showPopup = true
                        selectedIndex = selectableIndices.first
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if !isFocused {
                                showPopup = false
                                searchText = ""
                            }
                        }
                    }
                }
                .onAppear {
                    showPopup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        didAppear = true
                    }
                }
                .onSubmit {
                    if !searchText.isEmpty {
                        selectHighlightedOrFirst()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Chevron button
            Button {
                isFocused = true
                showPopup.toggle()
                if showPopup {
                    selectedIndex = selectableIndices.first
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
        )
        .onKeyPress(.downArrow) {
            if !showPopup {
                showPopup = true
                selectedIndex = selectableIndices.first
            } else {
                moveSelection(1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if showPopup {
                moveSelection(-1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if showPopup, let index = selectedIndex, index < displayItems.count {
                let item = displayItems[index]
                if !item.hasPrefix("---") {
                    select(item)
                    return .handled
                }
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showPopup {
                showPopup = false
                searchText = ""
                return .handled
            }
            return .ignored
        }
        .popover(isPresented: $showPopup, arrowEdge: .bottom) {
            dropdownContent
        }
    }
    
    // MARK: - Dropdown Content
    
    @ViewBuilder
    private var dropdownContent: some View {
        VStack(spacing: 0) {
            if displayItems.isEmpty || selectableIndices.isEmpty {
                Text(allowMultiSelect && !selectedItems.isEmpty ? "No more options" : "No matches")
                    .padding()
                    .foregroundStyle(.secondary)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                                if item.hasPrefix("---") {
                                    Divider()
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                } else {
                                    DropdownRow(
                                        text: item,
                                        isHighlighted: selectedIndex == index
                                    ) {
                                        select(item)
                                    }
                                    .id(index)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if let newIndex {
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(idealWidth: idealWidth, maxWidth: 350)
        .frame(minHeight: 80, maxHeight: 450)
    }
    
    // MARK: - Selection Helpers
    
    private func moveSelection(_ delta: Int) {
        guard !selectableIndices.isEmpty else { return }
        
        if selectedIndex == nil {
            selectedIndex = delta > 0 ? selectableIndices.first : selectableIndices.last
        } else if let currentIndex = selectedIndex,
                  let currentPosition = selectableIndices.firstIndex(of: currentIndex) {
            let newPosition = currentPosition + delta
            if newPosition >= 0 && newPosition < selectableIndices.count {
                selectedIndex = selectableIndices[newPosition]
            }
        } else {
            selectedIndex = selectableIndices.first
        }
    }
    
    private func selectHighlightedOrFirst() {
        guard showPopup else { return }
        
        if let index = selectedIndex, index < displayItems.count {
            let item = displayItems[index]
            if !item.hasPrefix("---") {
                select(item)
            }
        } else if let firstIndex = selectableIndices.first {
            select(displayItems[firstIndex])
        }
    }
    
    private func select(_ item: String) {
        guard !item.hasPrefix("---") else { return }
        
        if allowMultiSelect {
            var items = selectedItems
            items.insert(item)
            selection = items.sorted().joined(separator: ", ")
            searchText = ""
            selectedIndex = selectableIndices.first
        } else {
            selection = item
            searchText = item
            withAnimation {
                selectedIndex = displayItems.firstIndex(of: item)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                showPopup = false
                isFocused = false
            }
        }
    }
    
    private func removeSelection(_ item: String) {
        var items = selectedItems
        items.remove(item)
        withAnimation(.easeInOut(duration: 0.15)) {
            selection = items.sorted().joined(separator: ", ")
        }
    }
}

// MARK: - Backspace Detecting TextField (NSViewRepresentable)

struct BackspaceDetectingTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var onBackspaceWhenEmpty: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = BackspaceTextField()
        textField.placeholderString = placeholder
        textField.stringValue = text
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.onBackspaceWhenEmpty = onBackspaceWhenEmpty
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.placeholderString = placeholder
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if let backspaceField = nsView as? BackspaceTextField {
            backspaceField.onBackspaceWhenEmpty = onBackspaceWhenEmpty
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BackspaceDetectingTextField
        
        init(_ parent: BackspaceDetectingTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

class BackspaceTextField: NSTextField {
    var onBackspaceWhenEmpty: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        // Check for backspace (keyCode 51) when text is empty
        if event.keyCode == 51 && stringValue.isEmpty {
            onBackspaceWhenEmpty?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let onRemove: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
                .font(.system(size: 12))
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Dropdown Row

struct DropdownRow: View {
    let text: String
    let isHighlighted: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isHighlighted || isHovering ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .onHover { isHovering = $0 }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }
        
        return (CGSize(width: totalWidth, height: max(totalHeight, 20)), positions)
    }
}

// MARK: - Key Handler View

/*
struct KeyHandlerView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void
    static var currentHandler: ((NSEvent) -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Install a single global monitor only once
        if context.coordinator.monitor == nil {
            context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                //KeyHandlerView.currentHandler?(event)
                // Only swallow keys if the handler actually used them
                if let handler = KeyHandlerView.currentHandler {
                    handler(event)
                    // Ask handler if it "handled" Return (⏎)
                    if SearchablePicker.lastHandledKeyCodes.contains(Int(event.keyCode)) {
                        return nil
                    }
                }
                return event
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // When this picker has focus, set it as the active handler
        KeyHandlerView.currentHandler = onKeyDown
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var monitor: Any?
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

*/


/*
 HStack {
     Spacer()
     Image(systemName: "chevron.up.chevron.down.square.fill")
         .foregroundColor(.accentColor).opacity(0.5)
         .onTapGesture {
             searchText = ""
             showPopup = false
         }
 }
 */
