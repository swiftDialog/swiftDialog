//
//  ImageProcessing.swift
//  Dialog
//
//  Created by Bart E Reardon on 12/7/2023.
//

import Foundation
import Combine
import SwiftUI
//import WebViewKit
import WebKit
import SDWebImageSwiftUI

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
    var imgSize: CGFloat = 100
    var imgFromURL: Bool = false
    var imgFromBase64: Bool = false
    var imgFromAPP: Bool = false
    var nullImage: Bool = false
    var clipShapeRadius: CGFloat = 0
    var shouldClip: Bool = false
    var shouldResize: Bool = true
    var contentMode: ContentMode = .fit
    var showBackground: Bool = false

    init(_ path: String,
         corners: Bool = true,
         rezize: Bool = true,
         size: CGFloat = 100,
         content: ContentMode = .fit,
         showBackgroundOnError: Bool = false) {
        self.imgPath = path
        self.shouldResize = rezize
        self.imgSize = size
        self.contentMode = content
        self.showBackground = showBackgroundOnError

        switch path {
        case _ where path.hasPrefix("http"):
            asyncURL = URL(string: path)!
            imgFromURL = true
            self.shouldClip = true
        case _ where path.hasPrefix("base64"):
            imgFromBase64 = true
            self.shouldClip = true
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
        } else {
            self.clipShapeRadius = 2.5
        }

        if !showBackgroundOnError {
            imgSize = .infinity
        }
    }

    var body: some View {
        ZStack {
            if imgFromURL {
                if ["svg", "pdf"].contains(imgPath.split(separator: ".").last) {
                    let legacyImage = getImageFromPath(fileImagePath: imgPath, returnErrorImage: true)
                    Image(nsImage: legacyImage)
                        .resizable()
                        .interpolation(.high)
                // Reserved for future use
                } else if ["gif"].contains(imgPath.split(separator: ".").last) {
                    AnimatedImage(url: asyncURL)
                        .resizable()
                        .scaledToFit()
                } else {
                    AsyncImage(url: asyncURL) { phase in
                        if let image = phase.image {
                            if self.shouldResize {
                                image
                                    .resizable()
                                    .interpolation(.high)
                            } else {
                                image
                            }
                        } else if phase.error != nil {
                            // error image
                            ZStack {
                                if showBackground {
                                    RoundedRectangle(cornerRadius: clipShapeRadius, style: .continuous)
                                        .fill(.thickMaterial)
                                }
                                Image(systemName: "questionmark.square.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: imgSize)
                                    .symbolRenderingMode(.hierarchical)
                                    .font(Font.title.weight(.thin))
                                    .foregroundColor(.accentColor)
                            }
                        } else {
                            // placeholder image while the resource is loaded
                            RoundedRectangle(cornerRadius: clipShapeRadius, style: .continuous)
                                .fill(.regularMaterial)
                        }
                    }
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
                    .interpolation(.high)
            }
            if nullImage {
                Image(systemName: "circle.fill")
                    .foregroundColor(.clear)
            }
        }
        .aspectRatio(contentMode: contentMode)
        //.scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: clipShapeRadius))
    }
}

struct AnimatedGIFView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }
}

struct AnimatedGIFViewBlocked: View {
    let url: URL
    private let imageSize: CGSize?
    
    init(url: URL) {
        self.url = url
        self.imageSize = Self.getGIFSize(from: url)
    }
    
    var body: some View {
        ZStack {
            AnimatedGIFView(url: url)
            
            Color.clear
                .contentShape(Rectangle())
        }
        .aspectRatio(imageSize ?? CGSize(width: 1, height: 1), contentMode: .fit)
    }
    
    private static func getGIFSize(from url: URL) -> CGSize? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0
        
        return CGSize(width: width, height: height)
    }
}
