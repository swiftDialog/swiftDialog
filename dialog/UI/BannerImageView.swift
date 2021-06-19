//
//  BannerImageView.swift
//  Dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 27/3/21.
//

import Foundation
import SwiftUI

struct BannerImageView: View {
    
    var BannerImageOption: String = CLOptionText(OptionName: CLOptions.bannerImage)

    var body: some View {
        VStack {
            Image(nsImage: getImageFromPath(fileImagePath: BannerImageOption))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledToFill()
                .clipped()
        }

    }
}
