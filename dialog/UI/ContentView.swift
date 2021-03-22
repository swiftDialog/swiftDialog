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
            TitleView()
                .frame(width: appvars.windowWidth , height: appvars.titleHeight)
        }
        
        // Horozontal Line
        HStack{
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(height: 1)
        }
        .frame(width: (appvars.windowWidth * appvars.horozontalLineScale))
        .offset(y: -20)
        
        // Dialog content including message and image if visible
        HStack(alignment: .top) {
            DialogView()
                .frame(width: (appvars.windowWidth-10), height: (appvars.windowHeight * appvars.dialogContentScale * appvars.scaleFactor))
                //.border(Color.green)
        }.frame(alignment: .topLeading)
        //.border(Color.green) //debuging
        
        // Buttons
        HStack(alignment: .bottom) {
            if (CLOptionPresent(OptionName: CLOptions.buttonInfoTextOption) || CLOptionPresent(OptionName: CLOptions.infoButtonOption)) {
                MoreInfoButton()
            }
            Spacer()
            ButtonView()
        }
        .offset(y: 12)
        .frame(width: appvars.windowWidth-30, alignment: .center)
        //.border(Color.blue) //debuging
        
        // Window Setings (pinched from Nudge https://github.com/macadmins/nudge/blob/main/Nudge/UI/ContentView.swift#L19)
        HostingWindowFinder {window in
            window?.standardWindowButton(.closeButton)?.isHidden = true //hides the red close button
            window?.standardWindowButton(.miniaturizeButton)?.isHidden = true //hides the yellow miniaturize button
            window?.standardWindowButton(.zoomButton)?.isHidden = true //this removes the green zoom button
            window?.center() // center
            window?.isMovable = appvars.windowIsMoveable
            if appvars.windowOnTop {
                window?.level = .floating
            } else {
                window?.level = .normal
            }
            
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
        
        // process command line options that just display info and exit before we show the main window
        if CLOptionPresent(OptionName: CLOptions.getVersion) {
            printVersionString()
            exit(0)
        }
        if (CLOptionPresent(OptionName: CLOptions.helpOption) || CommandLine.arguments.count == 1) {
            print(helpText)
            exit(0)
        }
        if CLOptionPresent(OptionName: CLOptions.showLicense) {
            print(licenseText)
            exit(0)
        }
        if CLOptionPresent(OptionName: CLOptions.buyCoffee) {
            //I'm a teapot
            print("If you like this app and want to buy me a coffee https://www.buymeacoffee.com/bartreardon")
            exit(418)
        }
        
        if CLOptionPresent(OptionName: CLOptions.hideIcon) {
            iconVisible = false
        } else {
            iconVisible = true
        }
        
        if CLOptionPresent(OptionName: CLOptions.lockWindow) {
            appvars.windowIsMoveable = true
        }
        
        if CLOptionPresent(OptionName: CLOptions.forceOnTop) {
            appvars.windowOnTop = true
        }
                
        //----------
        
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
