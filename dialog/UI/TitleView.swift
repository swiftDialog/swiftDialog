//
//  TitleView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct TitleView: View {
    
    @State public var TitleViewOption: String = cloptions.titleOption.value// CLOptionText(OptionName: cloptions.titleOption, DefaultValue: appvars.titleDefault)

    var body: some View {
        if appvars.titleFontName == "" {
            Text(TitleViewOption)
                .font(.system(size: appvars.titleFontSize, weight: appvars.titleFontWeight))
                .foregroundColor(appvars.titleFontColour)
                .frame(width: appvars.windowWidth , height: appvars.titleHeight, alignment: .center)
        } else {
            Text(TitleViewOption)
                .font(.custom(appvars.titleFontName, size: appvars.titleFontSize))
                .foregroundColor(appvars.titleFontColour)
                .frame(width: appvars.windowWidth , height: appvars.titleHeight, alignment: .center)
        }
    }
}
