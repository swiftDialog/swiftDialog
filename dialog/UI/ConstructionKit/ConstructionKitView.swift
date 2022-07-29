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
        
        NavigationView {
            List() {
                Section(header: Text("Basic")) {
                    NavigationLink(destination: CKBasicsView(observedDialogContent: observedData)){
                        Text("Content")
                    }
                    NavigationLink(destination: CKWindowProperties(observedDialogContent: observedData)){
                        Text("Window")
                    }
                    NavigationLink(destination: CKIconView(observedDialogContent: observedData)){
                        Text("Icon")
                    }
                    NavigationLink(destination: CKButtonView(observedDialogContent: observedData)){
                        Text("Buttons")
                    }
                }
                Spacer()
            }
            .padding(10)
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 800, minHeight: 800)
        Divider()
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


