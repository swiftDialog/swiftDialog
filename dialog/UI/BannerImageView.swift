//
//  BannerImageView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 27/3/21.
//

import Foundation
import SwiftUI

struct BannerImageView: View {
    
    var BannerImageOption : String = ""
    var bannerHeight : CGFloat = 0
    let maxBannerHeight : CGFloat = 150
    
    init(imagePath: String) {
        BannerImageOption = imagePath
        bannerHeight = appvars.windowHeight * 0.2
        if bannerHeight > maxBannerHeight {
            bannerHeight = maxBannerHeight
        }
    }
    
    var body: some View {
        Image(nsImage: getImageFromPath(fileImagePath: BannerImageOption))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .scaledToFill()
            .frame(width: appvars.windowWidth, height: bannerHeight, alignment: .topLeading)
            .clipped()
    }
}
