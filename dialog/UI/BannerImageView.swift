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
    var bannerAdjustment : CGFloat = 0
    
    init(imagePath: String) {
        BannerImageOption = imagePath
        
        if cloptions.smallWindow.present {
            appvars.bannerHeight = 100
            bannerAdjustment = 10
        } else {
            appvars.bannerHeight = 150
        }
        //appvars.imageWidth = 0 // hides the side icon
    }
    
    //var BannerImageOption: String = CLOptionText(OptionName: CLOptions.bannerImage)

    var body: some View {
        Image(nsImage: getImageFromPath(fileImagePath: BannerImageOption))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .scaledToFill()
            .frame(width: appvars.windowWidth, height: appvars.bannerHeight-bannerAdjustment, alignment: .topLeading)
            .clipped()
    }
}
