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
    let maxBannerHeight: CGFloat = 130

    let blurRadius: CGFloat = 3
    let opacity: CGFloat = 0.5
    let blurOffset: CGFloat = 2

    //let size: CGFloat

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        writeLog("Displaying banner image \(observedDialogContent.args.bannerImage.value)")
        bannerWidth = observedDialogContent.windowWidth // appvars.windowWidth
        //bannerHeight = observedDialogContent.bannerImage.size.height*(bannerWidth / observedDialogContent.bannerImage.size.width)
        //if bannerHeight > maxBannerHeight {
        //    bannerHeight = maxBannerHeight
        //}
        //size = observedDialogContent.appProperties.titleFontSize
    }

    var body: some View {
        ZStack {
            DisplayImage(observedData.args.bannerImage.value, corners: false, showBackgroundOnError: true)
                .aspectRatio(contentMode: .fill)
                .scaledToFill()
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: bannerWidth, alignment: .topLeading)
                .frame(maxHeight: maxBannerHeight)
                .frame(minHeight: 100)
                .clipped()
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

