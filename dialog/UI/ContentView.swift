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
        appvars.debugBorderColour = Color.clear
        
        
        
        print("Window Height = \(appvars.windowHeight): Window Width = \(appvars.windowWidth)")
    }
    // puts the button bar jsut above the bottom row - 35 came from trial and error
    var buttonYPos = (appvars.windowHeight - 35)
    
    var bannerImagePresent = false
    var bannerAdjustment       = CGFloat(5)
        
    var body: some View {
        ZStack() {
            VStack {
                if bannerImagePresent {
                    HStack {
                        BannerImageView()
                            .frame(width: appvars.windowWidth, height: appvars.bannerHeight-bannerAdjustment, alignment: .topLeading)
                            //.border(Color.green)
                            .clipped()
                    }
                    .offset(y: appvars.bannerOffset)
                }
                // Dialog title
                HStack(alignment: .top){
                    TitleView()
                        .frame(width: appvars.windowWidth , height: appvars.titleHeight)
                        .offset(y: -15) // shift the title up a notch
                }
                .border(appvars.debugBorderColour) //debuging
                .frame(maxHeight: appvars.titleHeight)
                
                // Horozontal Line
                HStack{
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 1)
                }
                .frame(width: (appvars.windowWidth * appvars.horozontalLineScale))
                .offset(y: -20)
                .border(appvars.debugBorderColour) //debuging
                
                // Dialog content including message and image if visible
                HStack(alignment: .top) {
                    //VStack {
                        DialogView()
                            //.frame(width: (appvars.windowWidth-30), height: (appvars.windowHeight * appvars.dialogContentScale * appvars.scaleFactor))
                            //.border(Color.green)
                    //}
                }.frame(alignment: .topLeading)
                .border(appvars.debugBorderColour) //debuging
                //.border(Color.red) //debuging
                
                
                // Buttons
                Spacer() // force button to the bottom
                //Divider()
                
            }
            
            HStack() {
                if (CLOptionPresent(OptionName: CLOptions.buttonInfoTextOption) || CLOptionPresent(OptionName: CLOptions.infoButtonOption)) {
                    MoreInfoButton()
                }
                Spacer()
                //DropdownView().padding(20)
                ButtonView()
                    //.frame(alignment: .bottom)
            }
            .frame(width: appvars.windowWidth-30, alignment: .bottom)
            .border(Color.purple) //debuging
            .position(x: appvars.windowWidth/2, y: buttonYPos)
            
        }
        //.frame(width: appvars.windowWidth, height: appvars.windowHeight-10)
        //.border(Color.green) //debuging
            
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
