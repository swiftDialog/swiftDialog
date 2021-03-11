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
        let action: String = CLOptionText(OptionName: AppConstants.button1ActionOption, DefaultValue: "")
        
        if (action != "") {
            openSpecifiedURL(urlToOpen: action)
        }
        exit(0)
    }
    
    var body: some View {
        //secondary button
        HStack {
            if CLOptionPresent(OptionName: AppConstants.button2Option){
                Button(action: {exit(2)}, label: {
                    Text(AppVariables.button2Default)
                    }
                ).frame(minWidth: 36, alignment: .center)
                .keyboardShortcut(.cancelAction)
            } else if CLOptionPresent(OptionName: AppConstants.button2TextOption) {
                let button2Text: String = CLOptionText(OptionName: AppConstants.button2TextOption, DefaultValue: AppVariables.button2Default)
                Button(action: {exit(2)}, label: {
                    Text(button2Text)
                    }
                ).frame(minWidth: 36, alignment: .center)
                .keyboardShortcut(.cancelAction)
            }
        }
        // default button aka button 1
        let button1Text: String = CLOptionText(OptionName: AppConstants.button1TextOption, DefaultValue: AppVariables.button1Default)
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
    let buttonInfoAction: String = CLOptionText(OptionName: AppConstants.buttonInfoActionOption, DefaultValue: AppVariables.buttonInfoActionDefault)
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            if CLOptionPresent(OptionName: AppConstants.infoButtonOption) {
                Button(action: {openSpecifiedURL(urlToOpen: buttonInfoAction);exit(3)}, label: {
                    Text(AppVariables.buttonInfoDefault)
                    }
                ).frame(minWidth: 36, alignment: .center)
            } else if CLOptionPresent(OptionName: AppConstants.buttonInfoTextOption) {
                let buttonInfoText: String = CLOptionText(OptionName: AppConstants.buttonInfoTextOption, DefaultValue: AppVariables.buttonInfoDefault)
                Button(action: {openSpecifiedURL(urlToOpen: buttonInfoAction);exit(3)}, label: {
                    Text(buttonInfoText)
                    }
                ).frame(minWidth: 36, alignment: .center)
            }
        }
    }
    
}

// Utils.openSpecifiedURL(urlToOpen: "https://google.com")
