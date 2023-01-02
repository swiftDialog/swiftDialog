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
            LabelView(label: "ck-windowheight".localized)
            HStack {
                TextField("ck-heightvalue", value: $observedData.windowHeight, formatter: formatter )
                    .frame(width: 50)
                Slider(value: $observedData.windowHeight, in: 200...2000)
                    .frame(width: 200)
                Spacer()
            }
            LabelView(label: "ck-windowwidth".localized)
            HStack {
                TextField("ck-widthvalue", value: $observedData.windowWidth, formatter: formatter)
                    .frame(width: 50)
                Slider(value: $observedData.windowWidth, in: 200...2000)
                    .frame(width: 200)
                Spacer()
            }
            Group {
                LabelView(label: "ck-windowproperties".localized)
                //HStack {
                //    Text("Mini view")
                //        .frame(width: 100, alignment: .leading)
                //    Toggle("", isOn: $observedData.args.miniMode.present)
                //        .toggleStyle(.switch)
                //    Spacer()
                //}
                HStack {
                    Text("ck-presetsizes".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("ck-small", isOn: $observedData.args.smallWindow.present)
                        .toggleStyle(.switch)
                        .onChange(of: observedData.args.smallWindow.present, perform: { _ in
                            observedData.appProperties.scaleFactor = 0.75
                            observedData.iconSize = 120
                            if observedData.args.smallWindow.present {
                                observedData.args.bigWindow.present = false
                            }
                        })
                    Toggle("ck-big".localized, isOn: $observedData.args.bigWindow.present)
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
                    Text("ck-screenblur".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.blurScreen.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("ck-movable".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.movableWindow.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("ck-forceontop".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.forceOnTop.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("ck-progressbar".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.progressBar.present)
                        .toggleStyle(.switch)
                    TextField("ck-progressvalue".localized, value: $observedData.args.progressBar.value, formatter: formatter)
                        .frame(width: 50)
                    TextField("ck-progresstext".localized, text: $observedData.args.progressText.value)
                        .frame(width: 150)
                        .onChange(of: observedData.args.progressText.value, perform: { _ in
                            observedData.args.progressText.present = true
                        })
                    Spacer()
                }
            }
            HStack {
                Text("ck-bannerimage".localized)
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.bannerImage.present)
                    .toggleStyle(.switch)
                    .disabled(observedData.args.bannerImage.value == "")
                    .onChange(of: observedData.args.bannerImage.present, perform: { _ in
                        observedData.args.iconOption.present.toggle()
                    })
                Button("ck-select".localized)
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
                Text("ck-watermark".localized)
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.watermarkImage.present)
                    .toggleStyle(.switch)
                    .disabled(observedData.args.watermarkImage.value == "")
                Button("ck-select".localized)
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
                Picker("ck-fill".localized, selection: $observedData.args.watermarkFill.value)
                {
                    Text("").tag("")
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                HStack {
                    Text("ck-alpha".localized)
                    Slider(value: $bgAlpha, in: 0.0...1.0, step: 0.1)
                        .onChange(of: bgAlpha, perform: { _ in
                            observedData.args.watermarkAlpha.value = String(format: "%.1f", bgAlpha)
                        })
                }
                Picker("ck-scale".localized, selection: $observedData.args.watermarkScale.value)
                {
                    Text("").tag("")
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                Picker("ck-positoin".localized, selection: $observedData.args.watermarkPosition.value)
                {
                    Text("").tag("")
                    ForEach(positionArray, id: \.self) {
                        Text($0)
                    }
                }
            }
            .frame(width: 250)
            
            Spacer()
        }
        .padding(20)
    }
}
