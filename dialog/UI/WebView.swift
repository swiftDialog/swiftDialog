//
//  WebView.swift
//  dialog
//
//  Created by Bart Reardon on 21/3/2022.
//

import SwiftUI
import WebKit

struct HTMLView: NSViewRepresentable {
    typealias NSViewType = WKWebView
    
    let html = "<h1>Hello world</h1>"

    func makeNSView(context: Context) -> WKWebView {
        let webview = WKWebView()
        return webview
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}

struct WebView: View {
    var body: some View {
        HTMLView()
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WebView_Previews: PreviewProvider {
    static var previews: some View {
        WebView()
    }
}
