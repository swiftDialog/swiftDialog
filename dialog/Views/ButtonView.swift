//
//  ButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

struct ButtonView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    var progressSteps: CGFloat = appvars.timerDefaultSeconds

    var button1action: String = ""
    var buttonShellAction: Bool = false

    var defaultExit: Int32 = 0
    var cancelExit: Int32 = 2
    var infoExit: Int32 = 3

    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect() //trigger after 4 seconds

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        if observedDialogContent.args.timerBar.present {
            progressSteps = observedDialogContent.args.timerBar.value.floatValue()
        }

        if observedDialogContent.args.button1ShellActionOption.present {
            writeLog("Using button 1 shell action")
            button1action = observedDialogContent.args.button1ShellActionOption.value
            buttonShellAction = true
        } else if observedDialogContent.args.button1ActionOption.present {
            writeLog("Using button 1 action \(observedDialogContent.args.button1ActionOption.value)")
            button1action = observedDialogContent.args.button1ActionOption.value
        }
    }

    var body: some View {
        if ["centre","center","centred","centered"].contains(observedData.args.buttonStyle.value) {
            HStack {
                Spacer()
                    .frame(width: 20)

                if observedData.args.button2Option.present || observedData.args.button2TextOption.present {
                    Button(action: {
                        quitDialog(exitCode: observedData.appProperties.exit2.code, observedObject: observedData)
                    }, label: {
                        Text(observedData.args.button2TextOption.value)
                            .frame(minWidth: 50, alignment: .center)
                    }
                    )
                    .keyboardShortcut(observedData.appProperties.button2DefaultAction)
                }

                if !(observedData.args.button1TextOption.value == "none") {
                    Button(action: {
                        buttonAction(action: self.button1action, exitCode: 0, executeShell: self.buttonShellAction, observedObject: observedData)

                    }, label: {
                        Text(observedData.args.button1TextOption.value)
                            .frame(minWidth: 50, alignment: .center)
                    }
                    )
                    .keyboardShortcut(observedData.appProperties.button1DefaultAction)
                    .disabled(observedData.args.button1Disabled.present)
                }
                Spacer()
                    .frame(width: 20)
            }
        }
        else if ["stack"].contains(observedData.args.buttonStyle.value) {
            VStack {
                if !(observedData.args.button1TextOption.value == "none") {
                    Button(action: {
                        buttonAction(action: self.button1action, exitCode: 0, executeShell: self.buttonShellAction, observedObject: observedData)

                    }, label: {
                        Text(observedData.args.button1TextOption.value)
                            .frame(minWidth: 50, maxWidth: .infinity, alignment: .center)
                            .padding(5)
                    }
                    )
                    .keyboardShortcut(observedData.appProperties.button1DefaultAction)
                    .disabled(observedData.args.button1Disabled.present)
                }
                
                if observedData.args.button2Option.present || observedData.args.button2TextOption.present {
                    Button(action: {
                        quitDialog(exitCode: observedData.appProperties.exit2.code, observedObject: observedData)
                    }, label: {
                        Text(observedData.args.button2TextOption.value)
                            .frame(minWidth: 50, maxWidth: .infinity, alignment: .center)
                            .padding(5)
                    }
                    )
                    .keyboardShortcut(observedData.appProperties.button2DefaultAction)
                }
            }
        } else {
            // Buttons
            HStack {
                // info button or text
                if observedData.args.infoText.present {
                    Text(observedData.args.infoText.value)
                        .foregroundColor(.secondary.opacity(0.7))
                } else if observedData.args.infoButtonOption.present || observedData.args.buttonInfoTextOption.present {
                    MoreInfoButton(observedDialogContent: observedData)
                }
                Spacer()
                if observedData.args.timerBar.present {
                    TimerView(progressSteps: progressSteps, visible: !observedData.args.hideTimerBar.present, observedDialogContent: observedData)
                        .frame(alignment: .bottom)
                }
                if (observedData.args.timerBar.present && observedData.args.button1TextOption.present) || !observedData.args.timerBar.present || observedData.args.hideTimerBar.present {
                    // contains both button 1 and button 2

                    //secondary button
                    Spacer()
                    HStack {
                        if observedData.args.button2Option.present || observedData.args.button2TextOption.present {
                            let button2Text: String = observedData.args.button2TextOption.value
                            Button(action: {
                                quitDialog(exitCode: observedData.appProperties.exit2.code, observedObject: observedData)
                            }, label: {
                                Text(button2Text)
                                    .frame(minWidth: 40, alignment: .center)
                            }
                            )
                            .keyboardShortcut(observedData.appProperties.button2DefaultAction)
                            .disabled(observedData.args.button2Disabled.present)
                        }
                    }

                    // default button aka button 1
                    let button1Text: String = observedData.args.button1TextOption.value

                    if !(observedData.args.button1TextOption.value == "none") {
                        Button(action: {
                            buttonAction(action: self.button1action, exitCode: 0, executeShell: self.buttonShellAction, observedObject: observedData)

                        }, label: {
                            Text(button1Text)
                                .frame(minWidth: 40, alignment: .center)
                        }
                        )
                        .keyboardShortcut(observedData.appProperties.button1DefaultAction)
                        .disabled(observedData.args.button1Disabled.present)
                        .onReceive(timer) { _ in
                            if observedData.args.timerBar.present && !observedData.args.hideTimerBar.present {
                                observedData.args.button1Disabled.present = false
                            }
                        }
                    }

                    // Help Button
                    HelpButton(observedDialogContent: observedData)
                }
            }
        }
    }
}

struct HelpButton: View {
    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        if observedData.args.helpMessage.present {
            Button(action: {
                observedData.appProperties.showHelpMessage.toggle()
            }, label: {
                ZStack {
                    Circle()
                        .foregroundColor(.white)
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(.secondaryBackground)
                    Text("?")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 22, height: 22)
            })
            .focusable(false)
            .buttonStyle(HelpButtonStyle())
            .sheet(isPresented: $observedData.appProperties.showHelpMessage) {
                HelpView(observedContent: observedData)
            }
        }
    }

}

struct HelpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .help(String("help-hover".localized))
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct MoreInfoButton: View {
    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        HStack {
            Button(action: {
                    buttonAction(
                    action: observedData.args.buttonInfoActionOption.value,
                    exitCode: 3,
                    executeShell: false,
                    shouldQuit: observedData.args.quitOnInfo.present, observedObject: observedData)},
                   label: {
                    Text(observedData.args.buttonInfoTextOption.value)
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
