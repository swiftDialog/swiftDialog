//
//  InfoBoxView.swift
//  dialog
//
//  Created by Bart Reardon on 2/1/2023.
//

import SwiftUI
import Textual


struct InfoBoxView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    //var markdownStyle = MarkdownStyle(foregroundColor: .secondary)

    init(observedData: DialogUpdatableContent) {
        self.observedData = observedData
        writeLog("Displaying InfoBox")
    }

    var body: some View {
        ZStack {
            StructuredText(observedData.args.infoBox.value, parser: ColoredMarkdownParser())
                .multilineTextAlignment(.leading)
                .textual.structuredTextStyle(.gitHub)
                .focusable(false)
                .lineLimit(nil)
        }
        .frame(
              minWidth: 0,
              maxWidth: .infinity,
              minHeight: 0,
              maxHeight: .infinity,
              alignment: .topLeading
            )
    }
}


