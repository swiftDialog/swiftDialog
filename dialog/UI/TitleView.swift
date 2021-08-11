//
//  TitleView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI

struct TitleView: View {
    
    var TitleViewOption: String = CLOptionText(OptionName: CLOptions.titleOption, DefaultValue: appvars.titleDefault)

    var body: some View {
        Text(TitleViewOption)
            .font(.system(size: appvars.titleFontSize, weight: appvars.titleFontWeight))
            .foregroundColor(appvars.titleFontColour)
    }
}
