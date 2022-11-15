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
    
    var body: some View {
        if observedData.appProperties.titleFontName == "" {
            Text(observedData.args.titleOption.value)
                .font(.system(size: observedData.appProperties.titleFontSize, weight: observedData.appProperties.titleFontWeight))
                .foregroundColor(observedData.appProperties.titleFontColour)
        } else {
            Text(observedData.args.titleOption.value)
                .font(.custom(observedData.appProperties.titleFontName, size: observedData.appProperties.titleFontSize))
                .fontWeight(observedData.appProperties.titleFontWeight)
                .foregroundColor(observedData.appProperties.titleFontColour)
        }
    }
}
