//
//  progressBarView.swift
//  cltest
//
//  Created by Reardon, Bart on 11/8/21.
//

import SwiftUI
import Foundation

struct progressBarView: View {
    
    @State var progress: CGFloat = 0
    
    let barheight: CGFloat = 20
    var barRadius: CGFloat
    
    var steps: CGFloat = 10 // how many steps are there in the width of the progress bar
    // appvars.annimationSmoothing // defined in appVariables.swift - ugly. work out to self contain
    //let annimationSmoothing: Double = 20
    
    var barColour = Color.accentColor//.opacity(0.8)
    
    var timer = Timer.publish(every: 1.0/appvars.annimationSmoothing, on: .main, in: .common).autoconnect() //tick every 1 second
    
    init() {
        barRadius = barheight/2 // adjusting this affects "roundness"
        steps = NumberFormatter().number(from: CLOptionText(OptionName: CLOptions.timerBar, DefaultValue: "10")) as! CGFloat
        steps = steps*CGFloat(appvars.annimationSmoothing)
    }
        
    var body: some View {
        VStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle() // background of the progress bar
                        .fill(Color.secondary.opacity(0.5))
                    
                    Rectangle() // forground, aka "progress" of the progress bar
                        .fill(barColour)
                        .onReceive(timer) { _ in
                            if progress <= steps {
                                progress += 1
                                if progress > steps {
                                    quitDialog(exitCode: 4)
                                }
                            }
                        }
                        .frame(width: progress*(geometry.size.width/steps), height: barheight)
                        .clipShape(RoundedRectangle(cornerRadius: barRadius))
                        .animation(.easeInOut)

                        // Countdown timer area
                        // White text with black "outline"
                        // frame set to the same width as the progress bar and centered.
                        // add 0.8 wto the final steps count which will round to an int but briefly show 0 before the progress quits.
                    Text("\(Int((steps-progress)/CGFloat(appvars.annimationSmoothing)+0.8))")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 0.5) // create outline
                            .frame(width: geometry.size.width, height: barheight, alignment: .center)
                }
                // add layer mask to define the roundness of the progress bar
                .mask(Rectangle() // background of the progress bar
                        .frame(width: geometry.size.width, height: barheight)
                        .clipShape(RoundedRectangle(cornerRadius: barRadius))
                        .opacity(1)
                )
            }
        }
        .frame(height: barheight, alignment: .bottom) //needed to force limit the entire progress bar frame height
        .padding(10)
    }
}


