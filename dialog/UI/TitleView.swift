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
            Text(observedDialogContent.args.titleOption.value)
                .font(.system(size: observedDialogContent.titleFontSize, weight: appvars.titleFontWeight))
                .foregroundColor(observedDialogContent.titleFontColour)
        } else {
            Text(observedDialogContent.args.titleOption.value)
                .font(.custom(appvars.titleFontName, size: observedDialogContent.titleFontSize))
                .fontWeight(appvars.titleFontWeight)
                .foregroundColor(observedDialogContent.titleFontColour)
        }
    }
}
