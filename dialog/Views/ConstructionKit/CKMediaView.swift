//
//  CKMediaView.swift
//  dialog
//
//  Created by Bart Reardon on 30/9/2022.
//

import SwiftUI

struct CKMediaView: View {

    @ObservedObject var observedData: DialogUpdatableContent


    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        ScrollView { //buttons
            VStack {
                LabelView(label: "Video")
                HStack {
                    Toggle("Enable".localized, isOn: $observedData.args.video.present)
                        .toggleStyle(.switch)
                    Toggle("AutoPlay".localized, isOn: $observedData.args.autoPlay.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                Button("Select".localized) {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                          panel.allowedContentTypes = [.video, .movie, .mpeg4Movie, .quickTimeMovie]
                        if panel.runModal() == .OK {
                            observedData.args.video.value = panel.url?.path ?? "<none>"
                        }
                      }
                TextField("Filename".localized, text: $observedData.args.video.value)
                TextField("Caption".localized, text: $observedData.args.videoCaption.value)

            }
            VStack {
                LabelView(label: "Web".localized)
                HStack {
                    Toggle("Disabled".localized, isOn: $observedData.args.webcontent.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                TextField("URL".localized, text: $observedData.args.webcontent.value)
            }
        }
        .padding(20)
    }
}



