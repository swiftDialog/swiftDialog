//
//  VideoView.swift
//  dialog
//
//  Created by Bart Reardon on 12/10/21.
//

import SwiftUI
import AVKit


struct VideoView: View {
    
    @State var player = AVPlayer()
    var playerURL : URL
    var autoPlay : Bool
    var videoCaption : String
    
    init(videourl : String = "", autoplay : Bool = false, caption : String = "") {
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
            VideoPlayer(player: player)
                .onAppear {
                    player.replaceCurrentItem(with: AVPlayerItem(url: playerURL))
                    //player.replaceCurrentItem(with: AVPlayerItem(url: URL(fileURLWithPath: "/Users/rea094/Documents/screenshots/dep.mov")))
                    if autoPlay {
                        player.play()
                    }
                }
                //.frame(width: 600, height: 400)
            if videoCaption != "" {
                Text(videoCaption)
                    .font(.system(size: 20))
                    .italic()
            }
        }
    }
}
