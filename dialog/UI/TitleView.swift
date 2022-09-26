//
//  TitleView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct TitleView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var TitleViewOption: String = appArguments.titleOption.value// CLOptionText(OptionName: appArguments.titleOption, DefaultValue: appvars.titleDefault)
    //var TitleViewOption: String
        
    var body: some View {
        if appvars.titleFontName == "" {
            //Text(TitleViewOption)
            Text(observedData.args.titleOption.value)
                .font(.system(size: observedData.titleFontSize, weight: appvars.titleFontWeight))
                .foregroundColor(observedData.titleFontColour)
        } else {
            Text(observedData.args.titleOption.value)
                .font(.custom(appvars.titleFontName, size: observedData.titleFontSize))
                .fontWeight(appvars.titleFontWeight)
                .foregroundColor(observedData.titleFontColour)
        }
    }
}
