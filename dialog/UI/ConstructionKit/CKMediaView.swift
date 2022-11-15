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
                    Toggle("Enable", isOn: $observedData.args.video.present)
                        .toggleStyle(.switch)
                    Toggle("Autoplay", isOn: $observedData.args.autoPlay.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                Button("Select")
                      {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                          panel.allowedContentTypes = [.video, .movie, .mpeg4Movie, .quickTimeMovie]
                        if panel.runModal() == .OK {
                            observedData.args.video.value = panel.url?.path ?? "<none>"
                        }
                      }
                TextField("Filename", text: $observedData.args.video.value)
                TextField("Caption", text: $observedData.args.videoCaption.value)
                
            }
            VStack {
                LabelView(label: "Web")
                HStack {
                    Toggle("Disabled", isOn: $observedData.args.webcontent.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                TextField("URL", text: $observedData.args.webcontent.value)
            }
        }
    }
}



