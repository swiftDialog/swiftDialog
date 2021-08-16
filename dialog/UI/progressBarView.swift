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
    var barColour = Color.accentColor//.opacity(0.8)
    
    var steps: CGFloat// = 10 // how many steps are there in the width of the progress bar
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect() // tick every 1 second
    
    init(progressSteps : CGFloat?) {
        barRadius = barheight/2 // adjusting this affects "roundness"
        steps = progressSteps ?? 10
    }
        
    var body: some View {
        VStack {
            GeometryReader { geometry in
            // GeometryReader gets the size of the parent container and forms the progress bar to fit
            // Useful for arbitary window sizes
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
                        // the size of this overlay is the same as the number of steps in the progress bar
                        // this gives the impression of a continiously moving progress
                        .frame(width: progress*(geometry.size.width/steps), height: barheight)
                        .clipShape(RoundedRectangle(cornerRadius: barRadius))
                        // linear animation with duration set to the same as timer tick of 1 sec makes a continuious bar animation
                        .animation(.linear(duration: 1))

                        // Countdown timer area
                        // White text with black "outline"
                        // frame set to the same width as the progress bar and centered.
                    Text("\(Int(steps - progress))") // count down to 0
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


