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
    
    let barheight: CGFloat = 15
    var barRadius: CGFloat
    
    var steps: CGFloat = 10 // how many steps are there in the width of the progress bar
    
    var barColour = Color.accentColor//.opacity(0.8)
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect() //tick every 1 second
    
    init() {
        barRadius = barheight/2
        steps = NumberFormatter().number(from: CLOptionText(OptionName: CLOptions.timerBar, DefaultValue: "10")) as! CGFloat
    }
        
    var body: some View {
        VStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: geometry.size.width, height: barheight)
                        .clipShape(RoundedRectangle(cornerRadius: barRadius))
                    
                    Rectangle()
                        .fill(barColour)
                        .frame(width: progress*(geometry.size.width/steps), height: barheight)
                        .clipShape(RoundedRectangle(cornerRadius: barRadius))
                        //.frame(alignment: .leading)
                        .onReceive(timer) { input in
                            
                            if progress <= steps {
                                progress += 1
                                if progress > steps {
                                    quitDialog(exitCode: 4)
                                }
                            }
                                
                        }
                        .animation(.easeOut)

                        Text("\(Int(steps-progress))")
                            .foregroundColor(.white) // works fine for every accent colour except yellow
                            .frame(width: geometry.size.width, height: barheight, alignment: .center)
                }
            }
        }.padding(10)
        .frame(height: barheight, alignment: .bottom)
    }
}


