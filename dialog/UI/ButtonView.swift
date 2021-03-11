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
        let button2Text: String = CLOptionText(OptionName: AppConstants.button2TextOption, DefaultValue: AppVariables.button2Default)
        HStack {
            Button(action: {exit(2)}, label: {
                Text(button2Text)
                }
            ).frame(minWidth: 36, alignment: .center)
            .keyboardShortcut(.cancelAction)
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
    let buttonInfoText: String = CLOptionText(OptionName: AppConstants.buttonInfoTextOption, DefaultValue: AppVariables.buttonInfoDefault)
    let buttonInfoAction: String = CLOptionText(OptionName: AppConstants.buttonInfoActionOption, DefaultValue: AppVariables.buttonInfoActionDefault)
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Button(action: {openSpecifiedURL(urlToOpen: buttonInfoAction);exit(3)}, label: {
                Text(buttonInfoText)
                }
            ).frame(minWidth: 36, alignment: .center)
        }
    }
    
}

// Utils.openSpecifiedURL(urlToOpen: "https://google.com")
