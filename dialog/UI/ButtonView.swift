//
//  ButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

struct ButtonView: View {

    var button1action: String = ""
    var buttonShellAction: Bool = false
    
    init() {
        if CLOptionPresent(OptionName: CLOptions.button1ShellActionOption) {
            button1action = CLOptionText(OptionName: CLOptions.button1ShellActionOption)
            buttonShellAction = true
        } else if CLOptionPresent(OptionName: CLOptions.button1ActionOption) {
            button1action = CLOptionText(OptionName: CLOptions.button1ActionOption)
        }
    }
    
    var body: some View {
        //secondary button
        HStack {
            if CLOptionPresent(OptionName: CLOptions.button2Option){
                Button(action: {quitDialog(exitCode: 2)}, label: {
                    Text(appvars.button2Default)
                    }
                ).frame(minWidth: 36, alignment: .center)
                .keyboardShortcut(.cancelAction)
            } else if CLOptionPresent(OptionName: CLOptions.button2TextOption) {
                let button2Text: String = CLOptionText(OptionName: CLOptions.button2TextOption, DefaultValue: appvars.button2Default)
                Button(action: {quitDialog(exitCode: 2)}, label: {
                    Text(button2Text)
                    }
                ).frame(minWidth: 36, alignment: .center)
                .keyboardShortcut(.cancelAction)
            }
        }
        // default button aka button 1
        let button1Text: String = CLOptionText(OptionName: CLOptions.button1TextOption, DefaultValue: appvars.button1Default)
        HStack {
            Button(action: {buttonAction(action: self.button1action, exitCode: 0, executeShell: self.buttonShellAction)}, label: {
                Text(button1Text)
                }
            ).frame(minWidth: 36, alignment: .center)
            .keyboardShortcut(.defaultAction)
        }
    }
}

struct MoreInfoButton: View {
    let buttonInfoAction: String = CLOptionText(OptionName: CLOptions.buttonInfoActionOption, DefaultValue: appvars.buttonInfoActionDefault)
    
    
    
    var body: some View {
        HStack() {
            
            if CLOptionPresent(OptionName: CLOptions.infoButtonOption) {
                Button(action: {buttonAction(action: buttonInfoAction, exitCode: 3, executeShell: false)}, label: {
                    Text(appvars.buttonInfoDefault)
                    }
                ).frame(minWidth: 36, alignment: .center)
            } else if CLOptionPresent(OptionName: CLOptions.buttonInfoTextOption) {
                let buttonInfoText: String = CLOptionText(OptionName: CLOptions.buttonInfoTextOption, DefaultValue: appvars.buttonInfoDefault)
                Button(action: {buttonAction(action: buttonInfoAction, exitCode: 3, executeShell: false)}, label: {
                    Text(buttonInfoText)
                    }
                ).frame(minWidth: 36, alignment: .center)
            }
            Spacer()
        }
    }
    
}

// Utils.openSpecifiedURL(urlToOpen: "https://google.com")
