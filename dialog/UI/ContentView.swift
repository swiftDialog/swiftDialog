//
//  ContentView.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI

struct ContentView: View {

    var body: some View {
        // Dialog title
        HStack(alignment: .top){
            MessageTitle()
                .frame(width: AppVariables.windowWidth , height: 50)
                //.padding(20)
        }
        
        // Horozontal Line
        HStack{
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(height: 1)
        }
        .frame(width: (AppVariables.windowWidth*0.9))
        .offset(y: -20)
        
        // Dialog content
        HStack(alignment: .top) {
            MessageView()
                .frame(width: (AppVariables.windowWidth-10), height: (AppVariables.windowHeight*0.65))
        }.frame(alignment: .topLeading)
        //.border(Color.green)
        
        // Buttons
        HStack(alignment: .bottom) {
            if CLOptionPresent(OptionName: AppConstants.buttonInfoTextOption) {
                MoreInfoButton()
                    .offset(x: 20)
            }
            Spacer()
            ButtonView()
                .offset(x: -20)
        }
        //.border(Color.blue)
        
        // Window Setings
        HostingWindowFinder {window in
            window?.standardWindowButton(.closeButton)?.isHidden = true //hides the red close button
            window?.standardWindowButton(.miniaturizeButton)?.isHidden = true //hides the yellow miniaturize button
            window?.standardWindowButton(.zoomButton)?.isHidden = true //this removes the green zoom button
            window?.center() // center
            window?.isMovable = false // not movable
            NSApp.activate(ignoringOtherApps: true) // bring to forefront upon launch
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> ()

    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView()
        
        // process command line options to set variables
        if CLOptionPresent(OptionName: AppConstants.getVersion) {
            printVersionString()
            exit(0)
        }
        if (CLOptionPresent(OptionName: AppConstants.helpOption) || CommandLine.arguments.count == 1) {
            print(helpText)
            exit(0)
        }
        
        if CLOptionPresent(OptionName: AppConstants.hideIcon) {
            iconVisible = false
        } else {
            iconVisible = true
        }
        //----------
        
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
