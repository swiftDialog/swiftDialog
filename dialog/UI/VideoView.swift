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
            //GeometryReader() { geometry in
                VideoPlayer(player: player)
                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: playerURL))
                        if autoPlay {
                            player.play()
                        }
                    }
                    //.aspectRatio(contentMode: .fit)
                    //.frame(maxWidth : appvars.windowWidth)
            //}
            if videoCaption != "" {
                Text(videoCaption)
                    .font(.system(size: 20))
                    .italic()
            }
        }
    }
}
