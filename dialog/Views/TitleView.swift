//
//  TitleView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI
import Textual

struct TitleView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    var body: some View {
        InlineText(observedData.args.titleOption.value, parser: ColoredMarkdownParser())
            .font(
                observedData.appProperties.titleFontName.isEmpty ?
                Font.system(size: observedData.appProperties.titleFontSize, weight: observedData.appProperties.titleFontWeight, design: .default) :
                .custom(observedData.appProperties.titleFontName, size: observedData.appProperties.titleFontSize)
            )
            .fontWeight(observedData.appProperties.titleFontWeight)
        /*
        Text(observedData.args.titleOption.value)
            .titleFont(fontName: observedData.appProperties.titleFontName,
                       fontSize: observedData.appProperties.titleFontSize,
                       fontWeight: observedData.appProperties.titleFontWeight
            )
            .foregroundColor(observedData.appProperties.titleFontColour)
            .accessibilityHint(observedData.args.titleOption.value)
         */
    }
}

extension Text {
    func titleFont(fontName: String = "", fontSize: CGFloat = 30, fontWeight: Font.Weight = .bold) -> Text {
        if fontName.isEmpty {
            return self
                .font(.system(size: fontSize, weight: fontWeight))
        }
        return self
            .font(.custom(fontName, size: fontSize))
            .fontWeight(fontWeight)
    }
}
