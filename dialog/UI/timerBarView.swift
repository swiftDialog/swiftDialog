//
//  timerBarView.swift
//  cltest
//
//  Created by Reardon, Bart on 11/8/21.
//

import SwiftUI
import Foundation

struct timerBarView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    @State var progress: CGFloat = 0
    @State var progressWidth : CGFloat
    
    let barheight: CGFloat = 16
    var barRadius: CGFloat
    var barColour = Color.accentColor//.opacity(0.8)
    
    var steps: CGFloat// = 10 // how many steps are there in the width of the progress bar
    var timerSteps: CGFloat
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect() // tick every 1 second
    
    func numToHHMMSS(seconds: Int) -> String {
        var returnTime : String = "0"
        
        if seconds != 0 {
            let hours = (seconds / 3600) % 3600
            let minutes = (seconds / 60) % 60
            let seconds = seconds % 60
            if minutes < 1 && hours < 1 {
                returnTime = "\(seconds)"
            } else if hours < 1 {
                if minutes < 10 {
                    returnTime = String(format: "%d:%02d", minutes, seconds)
                } else {
                    returnTime = String(format: "%02d:%02d", minutes, seconds)
                }
            } else {
                if hours < 10 {
                    returnTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
                } else {
                    returnTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                }
                
            }
            //return String(format:"%d:%02d", minutes, seconds)
        }
        
        return returnTime
        
    }
    
    var barVisible: Bool
    
    init(progressSteps : CGFloat?, visible : Bool?, observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        barRadius = barheight/2 // adjusting this affects "roundness"
        steps = progressSteps ?? 10
        timerSteps = steps - 1
        barVisible = visible ?? true
        progressWidth = 0
    }
        
    var body: some View {
        if barVisible {
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
                                if progress <= timerSteps {
                                    progress += 1
                                    progressWidth = progress*(geometry.size.width/timerSteps)
                                    if progressWidth > geometry.size.width {
                                        // make sure the progress bar never exceeds the width of the display area else weird things happen
                                        progressWidth = geometry.size.width
                                    }
                                    if progress > timerSteps {
                                        // we've reched the end of the countdown
                                        // stop the timer
                                        timer.upstream.connect().cancel()
                                        // add a slight delay so the 0 countdown is displayed for a fraction of a second before dialog quits
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            quitDialog(exitCode: appvars.exit4.code)
                                        }
                                        //perform(quitDialog(exitCode: 4), with: nil, afterDelay: 4.0)
                                    }
                                }
                            }
                            // the size of this overlay is the same as the number of steps in the progress bar
                            // this gives the impression of a continiously moving progress
                            .frame(width: progressWidth, height: barheight)
                            // linear animation with duration set to the same as timer tick of 1 sec makes a continuious bar animation
                            .animation(.linear(duration: 1))

                            // Countdown timer area
                            // White text with black "outline"
                            // frame set to the same width as the progress bar and centered.
                        Text("\(numToHHMMSS(seconds: Int( steps-progress)))") // count down to 0 //Int(steps-progress)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0.5) // create outline
                                .frame(width: geometry.size.width, height: barheight, alignment: .center)
                    }
                    // add layer mask to define the roundness of the progress bar
                    .mask(Rectangle() // background of the progress bar
                            .frame(width: geometry.size.width, height: barheight)
                            .opacity(1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: barRadius))
                }
            }.frame(height: barheight, alignment: .bottom) //needed to force limit the entire progress bar frame height
            .padding(observedData.appProperties.sidePadding)
        } else {
            Spacer()
                .onReceive(timer) { _ in
                    if progress <= timerSteps {
                        progress += 1
                    }
                    if progress > timerSteps {
                        quitDialog(exitCode: appvars.exit4.code)
                    }
                }
        }
        
        
    }
}


