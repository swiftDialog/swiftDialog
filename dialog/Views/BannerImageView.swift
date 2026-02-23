//
//  BannerImageView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 27/3/21.
//

import Foundation
import SwiftUI
import Textual

struct BannerImageView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    //var bannerHeight: CGFloat = 0
    var bannerWidth: CGFloat = 0
    var maxBannerHeight: CGFloat = 130
    var minBannerHeight: CGFloat = 100

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
            minBannerHeight = maxBannerHeight
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
                    .frame(minHeight: minBannerHeight)
                    .clipped()
            }
            if observedData.args.bannerTitle.present {
                HStack {
                    if observedData.appProperties.titleFontAlignment.lowercased() == "right" {
                        Spacer()
                    }
                    InlineText(observedData.args.titleOption.value, parser: ColoredMarkdownParser())
                        .font(
                            observedData.appProperties.titleFontName.isEmpty ?
                                .system(size: observedData.appProperties.titleFontSize, weight: observedData.appProperties.titleFontWeight) :
                                    .custom(observedData.appProperties.titleFontName, size: observedData.appProperties.titleFontSize)
                        )
                        .fontWeight(observedData.appProperties.titleFontWeight)
                        .foregroundColor(observedData.appProperties.titleFontColour)
                        .accessibilityHint(observedData.args.titleOption.value)
                        .shadow(radius: observedData.appProperties.titleFontShadow ? blurRadius : 0)
                        .padding(appDefaults.topPadding)
                        .frame(alignment: .center)
                    if observedData.appProperties.titleFontAlignment.lowercased() == "left" {
                        Spacer()
                    }
                }
            }
        }
    }
}

