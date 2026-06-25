//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI
import SwiftyJSON

struct CKLabelView: View {
    var label: String
    var body: some View {
        VStack {
            Divider()
            HStack {
                Text(label)
                    .fontWeight(.bold)
                Spacer()
            }
        }
    }
}

struct CKWelcomeView: View {
    var body: some View {
        VStack {
            ZStack {
                IconView(image: "default")
                IconView(image: "sf=wrench.and.screwdriver.fill", alpha: 0.5, defaultColour: "white")
            }
            .frame(width: 150, height: 150)

            Text("Welcome to the swiftDialog builder".localized)
                .font(.largeTitle)
            Divider()
            Text("Select properties on the left to modify. swiftDialog will update to show the changes in realtime".localized)
                .foregroundColor(.secondary)
        }
    }
}

// Reusable icon picker used by the list and checkbox builders.
// Handles drag-and-drop of an image file plus an SF Symbol + colour popover.
struct CKIconPicker: View {
    @Binding var icon: String
    @Binding var sfPicker: Bool
    @Binding var sfSymbol: String
    @Binding var sfColour: String
    var opacity: Double = 1
    var onIconChange: ((String) -> Void)?

    @State private var tmpColour: Color = .clear

    var body: some View {
        IconView(image: icon, defaultImage: "sf=questionmark.square.dashed")
            .frame(width: 32, height: 32)
            .opacity(opacity)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async { icon = url.path }
                    }
                }
                return true
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(.gray.opacity(0.5))
            )
            .contentShape(Rectangle())
            .onTapGesture { sfPicker.toggle() }
            .onChange(of: icon) { _, newValue in onIconChange?(newValue) }
            .popover(isPresented: $sfPicker) {
                VStack {
                    HStack {
                        Text("sf=")
                        TextField("SF Symbol Name", text: $sfSymbol)
                            .onChange(of: sfSymbol) { _, sfName in
                                icon = "sf=\(sfName)"
                            }
                    }
                    ColorPicker("Colour".localized, selection: $tmpColour)
                        .onChange(of: tmpColour) { _, colour in
                            sfColour = colour.hexValue
                            icon = "sf=\(sfSymbol),color=\(colour.hexValue)"
                        }
                }
                .padding(20)
            }
    }
}

// Markdown editor for the message / infobox. Supports inline markdown, or loading a
// .md file / URL: in sourced mode the bound value holds the loaded content for the live
// preview while `source` keeps the reference that CKExport emits instead of the content.
struct CKMarkdownEditor: View {
    @Binding var text: String
    @Binding var source: String
    @Binding var present: Bool
    var minHeight: CGFloat = 60

    @State private var urlField: String = ""

    private func load(_ reference: String) {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        text = processTextString(getMarkdown(mdFilePath: trimmed), tags: appvars.systemInfo)
        source = trimmed
        present = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if source.isEmpty {
                HStack {
                    Text("Use markdown formatting to style the text".localized)
                    Spacer()
                    Button("From file…".localized) {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let path = panel.url?.path {
                            load(path)
                        }
                    }
                    TextField("…or URL".localized, text: $urlField)
                        .frame(maxWidth: 180)
                    Button("Load".localized) { load(urlField) }
                        .disabled(urlField.isEmpty)
                }
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .background(Color("editorBackgroundColour"))
                    .border(.primary, width: 0.5)
            } else {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Loaded from:".localized)
                    Text(source)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Reload".localized) { load(source) }
                    Button("Edit inline".localized) { source = "" }
                }
                .font(.caption)
                TextEditor(text: .constant(text))
                    .frame(minHeight: minHeight)
                    .background(Color("editorBackgroundColour"))
                    .border(.primary, width: 0.5)
                    .disabled(true)
                    .opacity(0.85)
                Text("Export references the source; the text above is a preview.".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Structured editor for a button symbol argument (button1symbol / button2symbol /
// infobuttonsymbol). Presents the SF Symbol properties as individual controls and
// recomposes the `name[,position,rendering,size,color|palette]` comma string that the
// CLI and ButtonBarView already understand.
struct CKSymbolEditor: View {
    @Binding var symbol: String
    @Binding var present: Bool

    @State private var name: String
    @State private var position: String
    @State private var renderingMode: String
    @State private var useColour: Bool
    @State private var colour: Color
    @State private var paletteColour1: Color
    @State private var paletteColour2: Color
    @State private var paletteColour3: Color
    @State private var paletteCount: Int
    @State private var useSize: Bool
    @State private var size: Double

    private let positions = ["leading", "trailing", "top", "bottom"]
    private let renderingModes = ["hierarchical", "monochrome", "multicolour", "palette"]

    init(symbol: Binding<String>, present: Binding<Bool>) {
        self._symbol = symbol
        self._present = present

        // Seed the controls from any existing spec so values aren't lost.
        let parts = symbol.wrappedValue.split(separator: ",").map { String($0) }
        var name = "", position = "", mode = ""
        var useColour = false, colour = Color.primary
        var palette: [Color] = [.red, .green, .blue], paletteCount = 2
        var useSize = false, size = 16.0
        if let first = parts.first { name = first }
        for part in parts.dropFirst() {
            let lower = part.lowercased()
            if ["leading", "trailing", "top", "bottom"].contains(lower) {
                position = lower
            } else if ["hierarchical", "monochrome", "multicolour", "palette"].contains(lower) {
                mode = lower
            } else if lower.hasPrefix("size="), let value = Double(part.dropFirst(5)) {
                useSize = true; size = value
            } else if lower.hasPrefix("color=") || lower.hasPrefix("colour=") {
                useColour = true
                colour = Color(argument: String(part.split(separator: "=").last ?? "primary"))
            } else if lower.hasPrefix("palette=") {
                mode = "palette"
                let colours = part.split(separator: "=").last?.split(separator: "-").map { Color(argument: String($0)) } ?? []
                for (index, value) in colours.prefix(3).enumerated() { palette[index] = value }
                paletteCount = min(max(colours.count, 2), 3)
            }
        }
        _name = State(initialValue: name)
        _position = State(initialValue: position)
        _renderingMode = State(initialValue: mode)
        _useColour = State(initialValue: useColour)
        _colour = State(initialValue: colour)
        _paletteColour1 = State(initialValue: palette[0])
        _paletteColour2 = State(initialValue: palette[1])
        _paletteColour3 = State(initialValue: palette[2])
        _paletteCount = State(initialValue: paletteCount)
        _useSize = State(initialValue: useSize)
        _size = State(initialValue: size)
    }

    private func compose() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            symbol = ""
            present = false
            return
        }
        var tokens = [trimmed]
        if !position.isEmpty { tokens.append(position) }
        if renderingMode == "palette" {
            let colours = [paletteColour1, paletteColour2, paletteColour3].prefix(paletteCount).map { $0.hexValue }
            tokens.append("palette=\(colours.joined(separator: "-"))")
        } else {
            if !renderingMode.isEmpty { tokens.append(renderingMode) }
            if useColour && renderingMode != "multicolour" { tokens.append("color=\(colour.hexValue)") }
        }
        if useSize { tokens.append("size=\(Int(size))") }
        symbol = tokens.joined(separator: ",")
        present = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: name.isEmpty ? "questionmark.square.dashed" : name)
                    .frame(width: 22, height: 22)
                TextField("SF Symbol name".localized, text: $name)
                    .onChange(of: name) { _, _ in compose() }
            }
            HStack {
                Picker("Position".localized, selection: $position) {
                    Text("Default".localized).tag("")
                    ForEach(positions, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: position) { _, _ in compose() }
                Picker("Render".localized, selection: $renderingMode) {
                    Text("Default".localized).tag("")
                    ForEach(renderingModes, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: renderingMode) { _, _ in compose() }
            }
            if renderingMode == "palette" {
                HStack {
                    Stepper("Palette colours: \(paletteCount)".localized, value: $paletteCount, in: 2...3)
                        .onChange(of: paletteCount) { _, _ in compose() }
                    ColorPicker("", selection: $paletteColour1).labelsHidden()
                        .onChange(of: paletteColour1) { _, _ in compose() }
                    ColorPicker("", selection: $paletteColour2).labelsHidden()
                        .onChange(of: paletteColour2) { _, _ in compose() }
                    if paletteCount == 3 {
                        ColorPicker("", selection: $paletteColour3).labelsHidden()
                            .onChange(of: paletteColour3) { _, _ in compose() }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Toggle("Colour".localized, isOn: $useColour)
                        .onChange(of: useColour) { _, _ in compose() }
                    ColorPicker("", selection: $colour).labelsHidden()
                        .disabled(!useColour || renderingMode == "multicolour")
                        .onChange(of: colour) { _, _ in compose() }
                    Spacer()
                }
            }
            HStack {
                Toggle("Custom size".localized, isOn: $useSize)
                    .onChange(of: useSize) { _, _ in compose() }
                if useSize {
                    Slider(value: $size, in: 8...48, step: 1)
                        .onChange(of: size) { _, _ in compose() }
                    Text("\(Int(size))")
                }
                Spacer()
            }
            if !symbol.isEmpty {
                Text(symbol)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct ConstructionKitView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State private var showExportConfirmation = false

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        // mark all standard fields visible
        observedDialogContent.args.titleOption.present = true
        observedDialogContent.args.titleFont.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.iconOption.present = true
        observedDialogContent.args.iconSize.present = true
        observedDialogContent.args.button1TextOption.present = true
        observedDialogContent.args.windowWidth.present = true
        observedDialogContent.args.windowHeight.present = true
        observedDialogContent.args.movableWindow.present = true

    }

    public func showConstructionKit() {

        var window: NSWindow!
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
               styleMask: [.titled, .closable, .miniaturizable, .resizable],
               backing: .buffered, defer: false)
        window.title = "swiftDialog Construction Kit"
        window.makeKeyAndOrderFront(self)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ConstructionKitView(observedDialogContent: observedData))
        placeWindow(window, size: CGSize(width: 700,
                                         height: 900), vertical: .center, horozontal: .right, offset: 10)
    }

    var body: some View {

        NavigationView {
            List {
                Section(header: Text("Basic".localized)) {
                    NavigationLink(destination: CKTitleView(observedDialogContent: observedData)) {
                        Text("Title Bar".localized)
                    }
                    NavigationLink(destination: CKMessageView(observedDialogContent: observedData)) {
                        Text("Message".localized)
                    }
                    NavigationLink(destination: CKWindowProperties(observedDialogContent: observedData)) {
                        Text("Window".localized)
                    }
                    NavigationLink(destination: CKIconView(observedDialogContent: observedData)) {
                        Text("Icon".localized)
                    }
                    NavigationLink(destination: CKSidebarView(observedDialogContent: observedData)) {
                        Text("Sidebar".localized)
                    }
                    NavigationLink(destination: CKButtonView(observedDialogContent: observedData)) {
                        Text("Buttons".localized)
                    }
                }
                Section(header: Text("Data Entry")) {
                    NavigationLink(destination: CKTextEntryView(observedDialogContent: observedData)) {
                        Text("Text Fields".localized)
                    }
                    //NavigationLink(destination: CKSelectListsView(observedDialogContent: observedData)) {
                    //    Text("Select Lists".localized)
                    //}
                    NavigationLink(destination: CKCheckBoxesView(observedDialogContent: observedData)) {
                        Text("Checkboxes".localized)
                    }
                }
                Section(header: Text("Advanced".localized)) {
                    NavigationLink(destination: CKListView(observedDialogContent: observedData)) {
                        Text("List Items".localized)
                    }
                    NavigationLink(destination: CKImageView(observedDialogContent: observedData)) {
                        Text("Images".localized)
                    }
                    NavigationLink(destination: CKMediaView(observedDialogContent: observedData)) {
                        Text("Media".localized)
                    }
                }
                Spacer()
                Section(header: Text("Export".localized)) {
                    NavigationLink(destination: CKOutputView(observedDialogContent: observedData) ) {
                        Text("Output".localized)
                    }
                }
            }
            .padding(10)

            CKWelcomeView()
        }
        .listStyle(SidebarListStyle())
        Divider()
        HStack {
            Button("Quit".localized) {
                quitDialog(exitCode: appDefaults.exit0.code)
            }
            Spacer()
            Button("Export Command".localized) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(CKExport.command(from: observedData), forType: .string)
                showExportConfirmation = true
            }
        }
        .padding(20)
        .alert("Copied to clipboard".localized, isPresented: $showExportConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The dialog command was copied to the clipboard.".localized)
        }
    }
}
