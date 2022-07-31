//
//  CKWindowProperties.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKWindowProperties: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        
        VStack {
            LabelView(label: "Window Height")
            HStack {
                TextField("Height value:", value: $observedData.windowHeight, formatter: NumberFormatter())
                    .frame(width: 50)
                Slider(value: $observedData.windowHeight, in: 200...2000)
                    .frame(width: 200)
                Spacer()
            }
            LabelView(label: "Window Width")
            HStack {
                TextField("Width value:", value: $observedData.windowWidth, formatter: NumberFormatter())
                    .frame(width: 50)
                Slider(value: $observedData.windowWidth, in: 200...2000)
                    .frame(width: 200)
                Spacer()
            }
            LabelView(label: "Window Properties")
            HStack {
                Text("Screen Background Blur")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.blurScreen.present)
                    .toggleStyle(.switch)
                Spacer()
            }
            HStack {
                Text("Movable")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.movableWindow.present)
                    .toggleStyle(.switch)
                Spacer()
            }
            HStack {
                Text("Force on Top")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.forceOnTop.present)
                    .toggleStyle(.switch)
                Spacer()
            }
            HStack {
                Text("Banner Image")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.bannerImage.present)
                    .toggleStyle(.switch)
                    .disabled(observedData.args.bannerImage.value == "")
                    .onChange(of: observedData.args.bannerImage.present, perform: { _ in
                        observedData.args.iconOption.present.toggle()
                    })
                Button("Select")
                      {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes = [.image]
                        if panel.runModal() == .OK {
                            observedData.args.bannerImage.value = panel.url?.path ?? ""
                        }
                      }
                TextField("", text: $observedData.args.bannerImage.value)
            }
            Spacer()
        }
        .padding(20)
    }
}
