//
//  InfoBoxView.swift
//  dialog
//
//  Created by Bart Reardon on 2/1/2023.
//

import SwiftUI
import MarkdownUI

struct InfoBoxView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    var markdownStyle = MarkdownStyle(foregroundColor: .secondary)
    
    var body: some View {
        HStack {
            Markdown(observedData.args.infoBox.value, baseURL: URL(string: "http://"))
                .multilineTextAlignment(.leading)
                .markdownStyle(markdownStyle)
                .focusable(false)
                .lineLimit(10)
        }
    }
}


