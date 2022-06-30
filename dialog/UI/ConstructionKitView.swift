//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI

struct ConstructionKitView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    //@State var titleColour : Color
    // values being updated
    //@State var dialogTitle : String
    
    
        
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        
        //dialogTitle = observedDialogContent.titleText
        //titleColour = .primary
    }
    
    public func showConstructionKit() {
        
        var window: NSWindow!
        window = NSWindow(
               contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
               styleMask: [.titled, .closable, .miniaturizable, .resizable],
               backing: .buffered, defer: false)
        window.title = "swiftDialog Construction Kit"
        window.makeKeyAndOrderFront(self)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ConstructionKitView(observedDialogContent: observedDialogContent))

    }
    
    var body: some View {
        VStack {
            VStack {   // title
                Text("Title")
                HStack {
                    TextField("", text: $observedDialogContent.args.titleOption.value)
                    ColorPicker("Colour",selection: $observedDialogContent.titleFontColour)
                    Button("Default") {
                        observedDialogContent.titleFontColour = .primary
                    }
                }
            }
            Divider()
            HStack {   // title
                Text("Message")
                TextEditor(text: $observedDialogContent.messageText)
            }
            Divider()
            VStack {
                Text("Window Size")
                HStack {
                    Text("Height")
                    Slider(value: $observedDialogContent.windowHeight, in: 0...2000)
                    //Text("Current Height value: \(observedDialogContent.windowHeight, specifier: "%.0f")")
                    TextField("Height value:", value: $observedDialogContent.windowHeight, formatter: NumberFormatter())
                        .frame(width: 50)
                }
                HStack {
                    Text("Width")
                    Slider(value: $observedDialogContent.windowWidth, in: 0...2000)
                    TextField("Width value:", value: $observedDialogContent.windowWidth, formatter: NumberFormatter())
                        .frame(width: 50)
                    //Text("Current Width value: \(observedDialogContent.windowWidth, specifier: "%.0f")")
                }
            }
            Divider()
            Group { // icon and icon overlay
                VStack {
                    Text("Icon")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.iconPresent)
                        Button("Select")
                              {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.allowedContentTypes = [.image]
                                if panel.runModal() == .OK {
                                    observedDialogContent.iconImage = panel.url?.path ?? "<none>"
                                }
                              }
                        TextField("", text: $observedDialogContent.iconImage)
                    }
                    HStack {
                        Text("Icon Size")
                        Slider(value: $observedDialogContent.iconSize, in: 0...400)
                        //Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
                        TextField("Size value:", value: $observedDialogContent.iconSize, formatter: NumberFormatter())
                            .frame(width: 50)
                    }
                }
                Divider()
                VStack {
                    Text("Overlay")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.overlayIconPresent)
                        Button("Select")
                              {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.allowedContentTypes = [.image]
                                if panel.runModal() == .OK {
                                    observedDialogContent.overlayIconImage = panel.url?.path ?? "<none>"
                                }
                              }
                        TextField("", text: $observedDialogContent.overlayIconImage)
                    }
                }
            }
            Divider()
            Group { //buttons
                VStack {
                    Text("Button1")
                    HStack {
                        Toggle("Enabled", isOn: $observedDialogContent.button1Disabled)
                        TextField("", text: $observedDialogContent.button1Value)
                    }
                }
                Divider()
                VStack {
                    Text("Button2")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.button2Present)
                        TextField("", text: $observedDialogContent.button2Value)
                    }
                }
                Divider()
                VStack {
                    Text("Info Button")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.infoButtonPresent)
                        TextField("", text: $observedDialogContent.infoButtonValue)
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Export JSON") {}
                Button("Export Command") {}
            }
        }
        .frame(width: 800, height: 600)
        .padding(20)
    }
}


