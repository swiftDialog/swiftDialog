//
//  TitleView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct TitleView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var TitleViewOption: String = cloptions.titleOption.value// CLOptionText(OptionName: cloptions.titleOption, DefaultValue: appvars.titleDefault)
    //var TitleViewOption: String
        
    var body: some View {
        if appvars.titleFontName == "" {
            //Text(TitleViewOption)
            Text(observedDialogContent.titleText)
                .font(.system(size: appvars.titleFontSize, weight: appvars.titleFontWeight))
                .foregroundColor(appvars.titleFontColour)
        } else {
            Text(observedDialogContent.titleText)
                .font(.custom(appvars.titleFontName, size: appvars.titleFontSize))
                .fontWeight(appvars.titleFontWeight)
                .foregroundColor(appvars.titleFontColour)
        }
    }
}
