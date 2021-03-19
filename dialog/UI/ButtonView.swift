//
//  ButtonView.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

struct ButtonView: View {

    private func button1Action() {
        let action: String = CLOptionText(OptionName: CLOptions.button1ActionOption, DefaultValue: "")
        
        if (action != "") {
            openSpecifiedURL(urlToOpen: action)
        }
        exit(0)
    }
    
    var body: some View {
        //secondary button
        HStack {
            if CLOptionPresent(OptionName: CLOptions.button2Option){
                Button(action: {exit(2)}, label: {
                    Text(appvars.button2Default)
                    }
                ).frame(minWidth: 36, alignment: .center)
                .keyboardShortcut(.cancelAction)
            } else if CLOptionPresent(OptionName: CLOptions.button2TextOption) {
                let button2Text: String = CLOptionText(OptionName: CLOptions.button2TextOption, DefaultValue: appvars.button2Default)
                Button(action: {exit(2)}, label: {
                    Text(button2Text)
                    }
                ).frame(minWidth: 36, alignment: .center)
                .keyboardShortcut(.cancelAction)
            }
        }
        // default button aka button 1
        let button1Text: String = CLOptionText(OptionName: CLOptions.button1TextOption, DefaultValue: appvars.button1Default)
        HStack {
            Button(action: {self.button1Action()}, label: {
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
        VStack(alignment: .center) {
            Spacer()
            if CLOptionPresent(OptionName: CLOptions.infoButtonOption) {
                Button(action: {openSpecifiedURL(urlToOpen: buttonInfoAction);exit(3)}, label: {
                    Text(appvars.buttonInfoDefault)
                    }
                ).frame(minWidth: 36, alignment: .center)
            } else if CLOptionPresent(OptionName: CLOptions.buttonInfoTextOption) {
                let buttonInfoText: String = CLOptionText(OptionName: CLOptions.buttonInfoTextOption, DefaultValue: appvars.buttonInfoDefault)
                Button(action: {openSpecifiedURL(urlToOpen: buttonInfoAction);exit(3)}, label: {
                    Text(buttonInfoText)
                    }
                ).frame(minWidth: 36, alignment: .center)
            }
        }
    }
    
}

// Utils.openSpecifiedURL(urlToOpen: "https://google.com")
