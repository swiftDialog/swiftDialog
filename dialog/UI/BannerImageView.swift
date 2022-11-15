//
//  BannerImageView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 27/3/21.
//

import Foundation
import SwiftUI

struct BannerImageView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var bannerImage     : NSImage
    var bannerHeight    : CGFloat = 0
    var bannerWidth     : CGFloat = 0
    let maxBannerHeight : CGFloat = 150
        
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
        
        bannerImage = getImageFromPath(fileImagePath: observedDialogContent.args.bannerImage.value)
        bannerWidth = observedDialogContent.windowWidth // appvars.windowWidth
        bannerHeight = bannerImage.size.height*(bannerWidth / bannerImage.size.width)
        if bannerHeight > maxBannerHeight {
            bannerHeight = maxBannerHeight
        }
    }
    
    var body: some View {
        Image(nsImage: bannerImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .scaledToFill()
            .frame(width: bannerWidth, height: bannerHeight, alignment: .topLeading)
            .clipped()
    }
}
