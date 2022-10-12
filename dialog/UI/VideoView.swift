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
    var youtubeContent : Bool = false
    
    init(videourl : String = "", autoplay : Bool = false, caption : String = "") {
        if videourl.contains("youtube") {
            youtubeContent = true
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
            if youtubeContent {
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
