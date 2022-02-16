//
//  ButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

struct ButtonView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent

    var button1action: String = ""
    var buttonShellAction: Bool = false
    
    var defaultExit : Int32 = 0
    var cancelExit  : Int32 = 2
    var infoExit    : Int32 = 3
    
    //@State private var button1disabled = false
    
    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect() //trigger after 4 seconds
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        
        if cloptions.button1ShellActionOption.present {
            button1action = cloptions.button1ShellActionOption.value
            buttonShellAction = true
        } else if cloptions.button1ActionOption.present {
            button1action = cloptions.button1ActionOption.value
        }
    }
    
    var body: some View {
        //secondary button
        Spacer()
        HStack {
            if cloptions.button2Option.present {
                Button(action: {
                    observedDialogContent.end()
                    quitDialog(exitCode: appvars.exit2.code)
                }, label: {
                    Text(appvars.button2Default)
                        .frame(minWidth: 40, alignment: .center)
                    }
                )
                .keyboardShortcut(.cancelAction)
            } else if cloptions.button2TextOption.present {
                let button2Text: String = observedDialogContent.button2Value
                Button(action: {
                    observedDialogContent.end()
                    quitDialog(exitCode: appvars.exit2.code)
                }, label: {
                    Text(button2Text)
                        .frame(minWidth: 40, alignment: .center)
                    }
                )
                .keyboardShortcut(.cancelAction)
            }
        }
        // default button aka button 1
        let button1Text: String = observedDialogContent.button1Value

        Button(action: {
            observedDialogContent.end()
            buttonAction(action: self.button1action, exitCode: 0, executeShell: self.buttonShellAction)
            
        }, label: {
            Text(button1Text)
                .frame(minWidth: 40, alignment: .center)
            }
        )
        .keyboardShortcut(.defaultAction)
        .disabled(observedDialogContent.button1Disabled)
        .onReceive(timer) { _ in
            if cloptions.timerBar.present && !cloptions.hideTimerBar.present {
                observedDialogContent.button1Disabled = false
            }
            //button1disabled = false
        }

    }
}

struct MoreInfoButton: View {
    let buttonInfoAction: String = cloptions.buttonInfoActionOption.value
    var buttonInfoText : String = cloptions.buttonInfoTextOption.value
       
    var body: some View {
        HStack() {
            Button(action: {buttonAction(action: buttonInfoAction, exitCode: 3, executeShell: false, shouldQuit: cloptions.quitOnInfo.present)}, label: {
                Text(buttonInfoText)
                    .frame(minWidth: 40, alignment: .center)
                }
            )
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
    
}
