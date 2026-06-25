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
