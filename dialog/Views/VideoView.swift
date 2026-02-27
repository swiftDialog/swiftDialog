//
//  VideoView.swift
//  dialog
//
//  Created by Bart Reardon on 12/10/21.
//

import SwiftUI
import AVKit
import WebViewKit
import WebKit


struct VideoView: View {

    @State var player = AVPlayer()
    var playerURL: URL
    var autoPlay: Bool
    var videoCaption: String
    var embeddedContent: Bool = false

    init(videourl: String = "", autoplay: Bool = false, caption: String = "") {
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
                // For YouTube/Vimeo, use custom HTML wrapper with iframe
                EmbeddedVideoWebView(embedURL: playerURL)
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

/// Custom WKWebView wrapper for embedded video content
/// This loads HTML with proper iframe configuration for YouTube/Vimeo
struct EmbeddedVideoWebView: NSViewRepresentable {
    let embedURL: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Enable media playback without user gesture (for autoplay support)
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        loadEmbeddedVideo(in: webView)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if the URL changes
        if webView.url != embedURL {
            loadEmbeddedVideo(in: webView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func loadEmbeddedVideo(in webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: #000; }
                .video-container { position: relative; width: 100%; height: 100%; }
                iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="\(embedURL.absoluteString)"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                        allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
        
        // Load HTML with base URL to avoid CORS issues
        webView.loadHTMLString(html, baseURL: embedURL)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            writeLog("EmbeddedVideoWebView navigation failed: \(error.localizedDescription)", logLevel: .error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            writeLog("EmbeddedVideoWebView provisional navigation failed: \(error.localizedDescription)", logLevel: .error)
        }
    }
}
