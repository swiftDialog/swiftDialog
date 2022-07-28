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
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    //@State var titleColour : Color
    // values being updated
    //@State var dialogTitle : String
    
    
        
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        
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
        window.title = "swiftDialog Construction Kit (ALPHA)"
        window.makeKeyAndOrderFront(self)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ConstructionKitView(observedDialogContent: observedData))

    }
    
    private func exportJSON() {
        var json = JSON()
        var jsonDEBUG = JSON()
        
        // copy modifyable objects into args
        observedData.args.iconSize.value = "\(observedData.iconSize)"
        observedData.args.windowWidth.value = "\(observedData.windowWidth)"
        observedData.args.windowHeight.value = "\(observedData.windowHeight)"
        
        let mirrored_appArguments = Mirror(reflecting: observedData.args)
        for (_, attr) in mirrored_appArguments.children.enumerated() {
            if let propertyValue = attr.value as? CLArgument {
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
                    TextField("", text: $observedData.args.titleOption.value)
                    ColorPicker("Colour",selection: $observedData.titleFontColour)
                    Button("Default") {
                        observedData.titleFontColour = .primary
                    }
                }
                HStack {
                    Text("Font Size: ")
                    Slider(value: $observedData.titleFontSize, in: 10...80)
                    TextField("value:", value: $observedData.titleFontSize, formatter: NumberFormatter())
                        .frame(width: 50)
                }
            }

            LabelView(label: "Message")
            HStack {   // title
                TextEditor(text: $observedData.args.messageOption.value)
                    .frame(minHeight: 50)
            }
            
            VStack {
                LabelView(label: "Window Height")
                HStack {
                    Slider(value: $observedData.windowHeight, in: 200...2000)
                    //Text("Current Height value: \(observedDialogContent.windowHeight, specifier: "%.0f")")
                    TextField("Height value:", value: $observedData.windowHeight, formatter: NumberFormatter())
                        .frame(width: 50)
                }
                LabelView(label: "Window Width")
                HStack {
                    Slider(value: $observedData.windowWidth, in: 200...2000)
                    TextField("Width value:", value: $observedData.windowWidth, formatter: NumberFormatter())
                        .frame(width: 50)
                    //Text("Current Width value: \(observedDialogContent.windowWidth, specifier: "%.0f")")
                }
            }
            Group { // icon and icon overlay
                VStack {
                    LabelView(label: "Icon")
                    HStack {
                        Toggle("Visible", isOn: $observedData.args.iconOption.present)
                        Button("Select")
                              {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.allowedContentTypes = [.image]
                                if panel.runModal() == .OK {
                                    observedData.args.iconOption.value = panel.url?.path ?? "<none>"
                                }
                              }
                        TextField("", text: $observedData.args.iconOption.value)
                    }
                    LabelView(label: "Icon Size")
                    HStack {
                        Slider(value: $observedData.iconSize, in: 0...400)
                        //Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
                        TextField("Size value:", value: $observedData.iconSize, formatter: NumberFormatter())
                            .frame(width: 50)
                    }
                }
                VStack {
                    LabelView(label: "Overlay")
                    HStack {
                        Toggle("Visible", isOn: $observedData.args.overlayIconOption.present)
                        Button("Select")
                              {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.allowedContentTypes = [.image]
                                if panel.runModal() == .OK {
                                    observedData.args.overlayIconOption.value = panel.url?.path ?? "<none>"
                                }
                              }
                        TextField("", text: $observedData.args.overlayIconOption.value)
                    }
                }
            }
            Group { //buttons
                VStack {
                    LabelView(label: "Button1")
                    HStack {
                        Toggle("Disabled", isOn: $observedData.args.button1Disabled.present)
                        TextField("", text: $observedData.args.button1TextOption.value)
                    }
                }
                VStack {
                    LabelView(label: "Button2")
                    HStack {
                        Toggle("Visible", isOn: $observedData.args.button2Option.present)
                        TextField("", text: $observedData.args.button2TextOption.value)
                    }
                }
                VStack {
                    LabelView(label: "Info Button")
                    HStack {
                        Toggle("Visible", isOn: $observedData.args.infoButtonOption.present)
                            .onChange(of: observedData.args.infoButtonOption.present, perform: { _ in
                                observedData.args.infoText.present.toggle()
                            })
                        Toggle("Quit on Info", isOn: $observedData.args.quitOnInfo.present)
                        Spacer()
                    }
                    HStack {
                        Text("Label: ")
                        TextField("", text: $observedData.args.buttonInfoTextOption.value)
                    }
                    HStack {
                        Text("Info Button Action: ")
                        TextField("", text: $observedData.args.buttonInfoActionOption.value)
                            .onChange(of: observedData.args.buttonInfoActionOption.value, perform: { _ in
                                observedData.args.buttonInfoActionOption.present = true
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
                .disabled(false)
                Button("Export Command") {}
                    .disabled(true)
            }
        }
        .padding(20)
    }
}


