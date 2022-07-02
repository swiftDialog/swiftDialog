//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI
import SwiftyJSON

struct LabelView: View {
    var label : String
    
    
    //init(label: String) {
    //    self.label = label
    //}
    
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

struct ConstructionKitView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    //@State var titleColour : Color
    // values being updated
    //@State var dialogTitle : String
    
    
        
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        
        // mark all standard fields visible
        observedDialogContent.args.titleOption.present = true
        observedDialogContent.args.titleFont.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.iconOption.present = true
        observedDialogContent.args.iconSize.present = true
        observedDialogContent.args.button1TextOption.present = true
        observedDialogContent.args.windowWidth.present = true
        observedDialogContent.args.windowHeight.present = true
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
        window.contentView = NSHostingView(rootView: ConstructionKitView(observedDialogContent: observedDialogContent))

    }
    
    private func exportJSON() {
        var json = JSON()
        var jsonDEBUG = JSON()
        //var propertyValue = (long: String(""),short: String(""),value : String(""), present : Bool(false))
        let mirrored_appArguments = Mirror(reflecting: observedDialogContent.args)
        for (_, attr) in mirrored_appArguments.children.enumerated() {
            if let propertyValue = attr.value as? (long: String, short: String, value: String, present: Bool) {
                if propertyValue.present && propertyValue.value != "" {
                    json[propertyValue.long].string = propertyValue.value
                }
                jsonDEBUG[propertyValue.long].string = propertyValue.value
          }
        }
        print("Generated JSON")
        print(json)
        print("DEBUG JSON")
        print(jsonDEBUG)
    }
    
    var body: some View {
        VStack {
            
            VStack {
                LabelView(label: "Title")
                HStack {
                    TextField("", text: $observedDialogContent.args.titleOption.value)
                    ColorPicker("Colour",selection: $observedDialogContent.titleFontColour)
                    Button("Default") {
                        observedDialogContent.titleFontColour = .primary
                    }
                }
                HStack {
                    Text("Font Size: ")
                    Slider(value: $observedDialogContent.titleFontSize, in: 10...80)
                    TextField("value:", value: $observedDialogContent.titleFontSize, formatter: NumberFormatter())
                        .frame(width: 50)
                }
            }

            LabelView(label: "Message")
            HStack {   // title
                TextEditor(text: $observedDialogContent.args.messageOption.value)
                    .frame(minHeight: 50)
            }
            
            VStack {
                LabelView(label: "--Window Size--")
                LabelView(label: "Height")
                HStack {
                    Slider(value: $observedDialogContent.windowHeight, in: 200...2000)
                    //Text("Current Height value: \(observedDialogContent.windowHeight, specifier: "%.0f")")
                    TextField("Height value:", value: $observedDialogContent.windowHeight, formatter: NumberFormatter())
                        .frame(width: 50)
                }
                LabelView(label: "Width")
                HStack {
                    Slider(value: $observedDialogContent.windowWidth, in: 200...2000)
                    TextField("Width value:", value: $observedDialogContent.windowWidth, formatter: NumberFormatter())
                        .frame(width: 50)
                    //Text("Current Width value: \(observedDialogContent.windowWidth, specifier: "%.0f")")
                }
            }
            Group { // icon and icon overlay
                VStack {
                    LabelView(label: "Icon")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.args.iconOption.present)
                        Button("Select")
                              {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.allowedContentTypes = [.image]
                                if panel.runModal() == .OK {
                                    observedDialogContent.args.iconOption.value = panel.url?.path ?? "<none>"
                                }
                              }
                        TextField("", text: $observedDialogContent.args.iconOption.value)
                    }
                    LabelView(label: "Icon Size")
                    HStack {
                        Slider(value: $observedDialogContent.iconSize, in: 0...400)
                        //Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
                        TextField("Size value:", value: $observedDialogContent.iconSize, formatter: NumberFormatter())
                            .frame(width: 50)
                    }
                }
                VStack {
                    LabelView(label: "Overlay")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.args.overlayIconOption.present)
                        Button("Select")
                              {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.allowedContentTypes = [.image]
                                if panel.runModal() == .OK {
                                    observedDialogContent.args.overlayIconOption.value = panel.url?.path ?? "<none>"
                                }
                              }
                        TextField("", text: $observedDialogContent.args.overlayIconOption.value)
                    }
                }
            }
            Group { //buttons
                VStack {
                    LabelView(label: "Button1")
                    HStack {
                        Toggle("Disabled", isOn: $observedDialogContent.args.button1Disabled.present)
                        TextField("", text: $observedDialogContent.args.button1TextOption.value)
                    }
                }
                VStack {
                    LabelView(label: "Button2")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.args.button2Option.present)
                        TextField("", text: $observedDialogContent.args.button2TextOption.value)
                    }
                }
                VStack {
                    LabelView(label: "Info Button")
                    HStack {
                        Toggle("Visible", isOn: $observedDialogContent.args.infoButtonOption.present)
                        Toggle("Quit on Info", isOn: $observedDialogContent.args.quitOnInfo.present)
                        Spacer()
                    }
                    HStack {
                        Text("Label: ")
                        TextField("", text: $observedDialogContent.args.buttonInfoTextOption.value)
                    }
                    HStack {
                        Text("Info Button Action: ")
                        TextField("", text: $observedDialogContent.args.buttonInfoActionOption.value)
                            .onChange(of: observedDialogContent.args.buttonInfoActionOption.value, perform: { _ in
                                observedDialogContent.args.buttonInfoActionOption.present = true
                            })
                        Spacer()
                    }
                }
            }
            
        }
        .frame(minWidth: 800, minHeight: 800)
        .padding(20)
        
        ZStack {
            Spacer()
            HStack {
                Spacer()
                Button("Export JSON") {
                    exportJSON()
                }
                Button("Export Command") {}
            }
        }
        .padding(20)
    }
}


