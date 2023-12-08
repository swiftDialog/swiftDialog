//
//  BannerImageView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 27/3/21.
//

import Foundation
import SwiftUI

struct BannerImageView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    //var bannerHeight: CGFloat = 0
    var bannerWidth: CGFloat = 0
    //var bannerHeight: CGFloat = 130
    var maxBannerHeight: CGFloat = 130

    let blurRadius: CGFloat = 3
    let opacity: CGFloat = 0.5
    let blurOffset: CGFloat = 2

    //let size: CGFloat

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        writeLog("Displaying banner image \(observedDialogContent.args.bannerImage.value)")
        bannerWidth = observedDialogContent.appProperties.windowWidth
        if observedDialogContent.args.bannerHeight.present {
            maxBannerHeight = observedDialogContent.args.bannerHeight.value.floatValue()
        }
    }

    var body: some View {
        ZStack {
            if observedData.args.bannerImage.value.range(of: "colo[u]?r=", options: .regularExpression) != nil {
                SolidColourView(colourValue: observedData.args.bannerImage.value)
                    .frame(maxHeight: maxBannerHeight)
                    //.frame(minHeight: 100)
            } else {
                DisplayImage(observedData.args.bannerImage.value, corners: false, showBackgroundOnError: true)
                    .aspectRatio(contentMode: .fill)
                    .scaledToFill()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: bannerWidth, alignment: .topLeading)
                    .frame(maxHeight: maxBannerHeight)
                    .frame(minHeight: 100)
                    .clipped()
            }
            if observedData.args.bannerTitle.present {
                ZStack {
                    if observedData.appProperties.titleFontShadow {
                        if observedData.appProperties.titleFontName == "" {
                            Text(observedData.args.titleOption.value)
                                .font(.system(size: observedData.appProperties.titleFontSize, weight: observedData.appProperties.titleFontWeight))
                                .foregroundColor(.black)
                                .offset(x: blurOffset, y: blurOffset)
                                .blur(radius: blurRadius)
                                .opacity(opacity)
                        } else {
                            Text(observedData.args.titleOption.value)
                                .font(.custom(observedData.appProperties.titleFontName, size: observedData.appProperties.titleFontSize))
                                .fontWeight(observedData.appProperties.titleFontWeight)
                                .foregroundColor(.black)
                                .offset(x: blurOffset, y: blurOffset)
                                .blur(radius: blurRadius)
                                .opacity(opacity)
                        }
                    }
                    if observedData.appProperties.titleFontName == "" {
                        Text(observedData.args.titleOption.value)
                            .font(.system(size: observedData.appProperties.titleFontSize, weight: observedData.appProperties.titleFontWeight))
                            .foregroundColor(observedData.appProperties.titleFontColour)
                            .accessibilityHint(observedData.args.titleOption.value)
                    } else {
                        Text(observedData.args.titleOption.value)
                            .font(.custom(observedData.appProperties.titleFontName, size: observedData.appProperties.titleFontSize))
                            .fontWeight(observedData.appProperties.titleFontWeight)
                            .foregroundColor(observedData.appProperties.titleFontColour)
                            .accessibilityHint(observedData.args.titleOption.value)
                    }
                }
                .padding(observedData.appProperties.topPadding)
                .frame(alignment: .center)
            }
        }
    }
}

