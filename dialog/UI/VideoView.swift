//
//  VideoView.swift
//  dialog
//
//  Created by Bart Reardon on 12/10/21.
//

import SwiftUI
import AVKit
import WebViewKit


struct VideoView: View {
    
    @State var player = AVPlayer()
    var playerURL : URL
    var autoPlay : Bool
    var videoCaption : String
    var embeddedContent : Bool = false
    
    init(videourl : String = "", autoplay : Bool = false, caption : String = "") {
        writeLog("Showing video player for \(videourl). Autoplay is \(autoplay), caption is \(caption)")
        if videourl.contains("youtube") || videourl.contains("vimeo") {
            writeLog("Displaying youtube or vimeo video. embedded content is enabled")
            embeddedContent = true
        }
        if videourl.hasPrefix("http") {
            playerURL = URL(string: videourl)!
        } else {
            playerURL = URL(fileURLWithPath: videourl)
        }
        autoPlay = autoplay
        videoCaption = caption
    }
        
    var body: some View {
        VStack {
            if embeddedContent {
                WebView(url: playerURL) { webView in
                }
            } else {
                VideoPlayer(player: player)
                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: playerURL))
                        if autoPlay {
                            player.play()
                        }
                    }
            }

            if videoCaption != "" {
                Text(videoCaption)
                    .font(.system(size: 20))
                    .italic()
            }
        }
    }
}
