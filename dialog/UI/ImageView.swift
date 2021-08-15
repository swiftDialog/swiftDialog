//
//  ImageView.swift
//  dialog
//
//  Created by Reardon, Bart (IM&T, Yarralumla) on 15/8/21.
//

import SwiftUI

struct ImageView: View {
    
    var imagePath: String = ""
    var mainImage: NSImage
    var imageCaption: String = ""
    
    init(imagePath: String? = "", caption: String? = "") {
        mainImage = getImageFromPath(fileImagePath: imagePath ?? "")
        imageCaption = caption ?? ""
    }
    
    var body: some View {
        VStack {
            Image(nsImage: mainImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(radius: 3)
            Text(imageCaption)
                .font(.system(size: 20))
                .italic()
        }
    }
}
