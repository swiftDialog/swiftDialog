//
//  ContentView.swift
//  dialog
//
//  Created by Bart Reardon on 9/3/21.
//

import SwiftUI

struct ContentView: View {
    init() {
        //appvars.windowHeight = appvars.windowHeight + 200
        if CLOptionPresent(OptionName: CLOptions.bannerImage) {
            if CLOptionPresent(OptionName: CLOptions.smallWindow) {
                appvars.bannerHeight = 100
                bannerAdjustment = 10
            } else {
                appvars.bannerHeight = 150
            }
            appvars.bannerOffset = -30
            bannerImagePresent = true
            appvars.imageWidth = 0 // hides the side icon
            
            //adjust the position of the button bar by adding the banner height and ofsetting the default banner height of -10
            buttonYPos = (buttonYPos +  appvars.bannerHeight + 10)
        }
        //print("Window Height = \(appvars.windowHeight): Window Width = \(appvars.windowWidth)")
    }
    // puts the button bar jsut above the bottom row - 35 came from trial and error
    var buttonYPos = (appvars.windowHeight)
    
    var bannerImagePresent = false
    var bannerAdjustment       = CGFloat(5)
        
    var body: some View {
        ZStack() {
        // this stack controls the main view. Consists of a VStack containing all the content, and a HStack positioned at the bottom of the display area
            VStack {
                if bannerImagePresent {
                    BannerImageView()
                        .frame(width: appvars.windowWidth, height: appvars.bannerHeight-bannerAdjustment, alignment: .topLeading)
                        .clipped()
                        .border(appvars.debugBorderColour, width: 2)
                }

                // Dialog title
                TitleView()
                    .frame(width: appvars.windowWidth , height: appvars.titleHeight, alignment: .center)
                    .border(appvars.debugBorderColour, width: 2)
                    .offset(y: 10) // shift the title down a notch
                
                // Horozontal Line
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(height: 1)
                    .frame(width: (appvars.windowWidth * appvars.horozontalLineScale), height: 2)
                    .offset(y: -5) //shift the line down a notch
            
                // Dialog content including message and image if visible
                DialogView()
                    .frame(alignment: .topLeading)
            }
                
            // Buttons
            HStack() {
                MoreInfoButton()
                Spacer()
                ButtonView() // contains both button 1 and button 2
            }
            .frame(width: appvars.windowWidth-30, alignment: .bottom)
            .border(appvars.debugBorderColour, width: 2)
            .position(x: appvars.windowWidth/2, y: buttonYPos-5)
            
            
        }
            
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
            //window?.toggleFullScreen(self)
            
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
                
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
