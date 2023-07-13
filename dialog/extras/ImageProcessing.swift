//
//  ImageProcessing.swift
//  Dialog
//
//  Created by Bart E Reardon on 12/7/2023.
//

import Foundation
import Combine
import SwiftUI

enum ImageSource {
    case remote(url: URL?)
    case local(name: String)
    case app(name: String)

}

struct DisplayImage: View {

    // A view that takes a string argument and renders the appropriate image
    // Will determine for local images, remote (http) base64 and load app icons.

    var asyncURL: URL = URL(string: "https://macadmins.org")!
    var imgPath: String = ""
    var imgFromURL: Bool = false
    var imgFromBase64: Bool = false
    var imgFromAPP: Bool = false
    var nullImage: Bool = false
    var clipShapeRadius: CGFloat = 0
    var shouldClip: Bool = false
    var shouldResize: Bool = true

    init(_ path: String, corners: Bool = true, rezize: Bool = true) {
        self.imgPath = path
        self.shouldResize = rezize

        switch path {
        case _ where path.hasPrefix("http"):
            asyncURL = URL(string: path)!
            imgFromURL = true
        case _ where path.hasPrefix("base64"):
            imgFromBase64 = true
        case _ where ["app", "prefPane", "framework"].contains(path.split(separator: ".").last):
            imgFromAPP = true
            self.shouldClip = false
        case "none":
            nullImage = true
        default:
            asyncURL = NSURL(fileURLWithPath: path) as URL
            imgFromURL = true
            self.shouldClip = true
        }

        if corners && self.shouldClip {
            self.clipShapeRadius = 10
        }
    }

    var body: some View {

        ZStack {
            if imgFromURL {
                AsyncImage(url: asyncURL) { image in
                    if self.shouldResize {
                        image
                            .resizable()
                            .interpolation(.medium)
                    } else {
                        image
                    }
                } placeholder: {
                    Image(systemName: "questionmark.app.fill")
                        .resizable()
                        .symbolRenderingMode(.hierarchical)
                        .font(Font.title.weight(.thin))
                        .foregroundColor(.accentColor)
                }
            }
            if imgFromBase64 {
                Image(nsImage: getImageFromBase64(base64String: imgPath.replacingOccurrences(of: "base64=", with: "")))
                    .resizable()
                    .interpolation(.medium)
            }
            if imgFromAPP {
                Image(nsImage: getAppIcon(appPath: imgPath))
                    .resizable()
                    .interpolation(.medium)
            }
            if nullImage {
                Image(systemName: "circle.fill")
                    .foregroundColor(.clear)
            }
        }
        .aspectRatio(contentMode: .fit)
        //.scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: clipShapeRadius))
    }
}

