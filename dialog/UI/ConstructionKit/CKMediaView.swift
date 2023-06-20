//
//  CKMediaView.swift
//  dialog
//
//  Created by Bart Reardon on 30/9/2022.
//

import SwiftUI

struct CKMediaView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        VStack { //buttons
            VStack {
                LabelView(label: "Video")
                HStack {
                    Toggle("ck-enable".localized, isOn: $observedData.args.video.present)
                        .toggleStyle(.switch)
                    Toggle("ck-autoplay".localized, isOn: $observedData.args.autoPlay.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                Button("ck-select".localized) {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                          panel.allowedContentTypes = [.video, .movie, .mpeg4Movie, .quickTimeMovie]
                        if panel.runModal() == .OK {
                            observedData.args.video.value = panel.url?.path ?? "<none>"
                        }
                      }
                TextField("ck-filename".localized, text: $observedData.args.video.value)
                TextField("ck-caption".localized, text: $observedData.args.videoCaption.value)
                
            }
            VStack {
                LabelView(label: "ck-web".localized)
                HStack {
                    Toggle("ck-disabled".localized, isOn: $observedData.args.webcontent.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                TextField("ck-url".localized, text: $observedData.args.webcontent.value)
            }
        }
    }
}



