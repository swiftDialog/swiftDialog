//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI

struct ConstructionKitView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    
    // values being updated
    //@State var dialogTitle : String
    
    
        
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        
        //dialogTitle = observedDialogContent.titleText
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
            HStack {   // title
                Text("Title")
                TextField("", text: $observedDialogContent.titleText)
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
                    Text("Current Height value: \(observedDialogContent.windowHeight, specifier: "%.0f")")
                }
                HStack {
                    Text("Width")
                    Slider(value: $observedDialogContent.windowWidth, in: 0...2000)
                    Text("Current Width value: \(observedDialogContent.windowWidth, specifier: "%.0f")")
                }
            }
            HStack {
                Text("Icon")
                Toggle("Visible", isOn: $observedDialogContent.iconPresent)
                TextField("", text: $observedDialogContent.iconImage)
            }
            HStack {
                Text("Icon Size")
                Slider(value: $observedDialogContent.iconSize, in: 0...400)
                Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
            }
            HStack {
                Text("Overlay")
                Toggle("Visible", isOn: $observedDialogContent.overlayIconPresent)
                TextField("", text: $observedDialogContent.overlayIconImage)
            }
        }
        .frame(width: 800, height: 600)
        .padding(20)
    }
}


