//
//  CKWindowProperties.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKWindowProperties: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    @State var bgAlpha : Double = 0.5
    let positionArray = ["topleft", "left", "bottomleft", "top", "center", "bottom", "topright", "right", "bottomright"]
    let fillScaleArray = ["fill", "fit"]
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        
        VStack {
            LabelView(label: "Window Height")
            HStack {
                TextField("Height value:", value: $observedData.windowHeight, formatter: formatter )
                    .frame(width: 50)
                Slider(value: $observedData.windowHeight, in: 200...2000)
                    .frame(width: 200)
                Spacer()
            }
            LabelView(label: "Window Width")
            HStack {
                TextField("Width value:", value: $observedData.windowWidth, formatter: formatter)
                    .frame(width: 50)
                Slider(value: $observedData.windowWidth, in: 200...2000)
                    .frame(width: 200)
                Spacer()
            }
            Group {
                LabelView(label: "Window Properties")
                //HStack {
                //    Text("Mini view")
                //        .frame(width: 100, alignment: .leading)
                //    Toggle("", isOn: $observedData.args.miniMode.present)
                //        .toggleStyle(.switch)
                //    Spacer()
                //}
                HStack {
                    Text("Preset Sizes")
                        .frame(width: 100, alignment: .leading)
                    Toggle("Small", isOn: $observedData.args.smallWindow.present)
                        .toggleStyle(.switch)
                        .onChange(of: observedData.args.smallWindow.present, perform: { _ in
                            observedData.appProperties.scaleFactor = 0.75
                            observedData.iconSize = 120
                            if observedData.args.smallWindow.present {
                                observedData.args.bigWindow.present = false
                            }
                        })
                    Toggle("Big", isOn: $observedData.args.bigWindow.present)
                        .toggleStyle(.switch)
                        .onChange(of: observedData.args.bigWindow.present, perform: { _ in
                            observedData.appProperties.scaleFactor = 1.25
                            if observedData.args.bigWindow.present {
                                observedData.args.smallWindow.present = false
                            }
                        })
                    Spacer()
                }
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
            HStack {
                Text("Watermark")
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.watermarkImage.present)
                    .toggleStyle(.switch)
                    .disabled(observedData.args.watermarkImage.value == "")
                Button("Select")
                {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.image]
                    if panel.runModal() == .OK {
                        observedData.args.watermarkImage.value = panel.url?.path ?? ""
                    }
                }
                TextField("", text: $observedData.args.watermarkImage.value)
            }
            VStack {
                Picker("Fill", selection: $observedData.args.watermarkFill.value)
                {
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                TextField("Aplha", text: $observedData.args.watermarkAlpha.value)
                HStack {
                    Text("Alpha")
                    Slider(value: $bgAlpha, in: 0.0...1.0, step: 0.1)
                        .onChange(of: bgAlpha, perform: { _ in
                            observedData.args.watermarkAlpha.value = String(bgAlpha)
                        })
                }
                Picker("Scale", selection: $observedData.args.watermarkScale.value)
                {
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                Picker("Position", selection: $observedData.args.watermarkPosition.value)
                {
                    ForEach(positionArray, id: \.self) {
                        Text($0)
                    }
                }
            }
            Spacer()
        }
        .padding(20)
    }
}
