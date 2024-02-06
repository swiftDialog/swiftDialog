//
//  CKWindowProperties.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKWindowProperties: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var bgAlpha: Double = 0.5
    @State var bgColour: Color = .white
    @State var bannerColour: Color = .white
    @State var bannerHeight: CGFloat

    let positionArray = ["topleft", "left", "bottomleft", "top", "center", "bottom", "topright", "right", "bottomright"]
    let fillScaleArray = ["fill", "fit"]

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        bannerHeight = observedDialogContent.args.bannerHeight.value.floatValue()
    }

    var body: some View {

        VStack {
            LabelView(label: "ck-windowheight".localized)
            HStack {
                TextField("ck-heightvalue", value: $observedData.appProperties.windowHeight, formatter: displayAsInt )
                    .frame(width: 50)
                Slider(value: $observedData.appProperties.windowHeight, in: 200...2000)
                    .frame(width: 200)
                    .onChange(of: observedData.appProperties.windowHeight) { height in
                        observedData.appProperties.windowHeight = height.rounded()
                    }
                Spacer()
            }
            LabelView(label: "ck-windowwidth".localized)
            HStack {
                TextField("ck-widthvalue", value: $observedData.appProperties.windowWidth, formatter: displayAsInt)
                    .frame(width: 50)
                Slider(value: $observedData.appProperties.windowWidth, in: 200...2000)
                    .frame(width: 200)
                    .onChange(of: observedData.appProperties.windowWidth) { width in
                        observedData.appProperties.windowWidth = width.rounded()
                    }
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
                LabelView(label: "Configurations")
                HStack {
                    Text("Will not apply to live view").italic()
                    Spacer()
                }
                HStack {
                    Text("Window Buttons")
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.windowButtonsEnabled.present)
                        .toggleStyle(.switch)
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
                LabelView(label: "Progress Bar")
                HStack {
                    Text("ck-progressbar".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.progressBar.present)
                        .toggleStyle(.switch)
                    TextField("ck-progressvalue".localized, value: $observedData.args.progressBar.value, formatter: displayAsInt)
                        .frame(width: 50)
                    TextField("ck-progresstext".localized, text: $observedData.args.progressText.value)
                        .frame(width: 150)
                        .onChange(of: observedData.args.progressText.value, perform: { _ in
                            observedData.args.progressText.present = true
                        })
                    Spacer()
                }
            }
            Group {
                LabelView(label: "ck-bannerimage".localized)
                HStack {
                    Toggle("Enabled", isOn: $observedData.args.bannerImage.present)
                        .toggleStyle(.switch)
                        .disabled(observedData.args.bannerImage.value == "")
                        .onChange(of: observedData.args.bannerImage.present, perform: { isEnabled in
                            observedData.args.iconOption.present.toggle()
                            observedData.args.bannerTitle.present = isEnabled
                        })
                    Toggle("Banner Title", isOn: $observedData.args.bannerTitle.present)
                        .toggleStyle(.switch)
                        //.disabled(observedData.args.bannerImage.value == "")
                        .onChange(of: observedData.args.bannerTitle.present, perform: { isEnabled in
                            if isEnabled {
                                observedData.appProperties.titleFontColour = Color.white
                            } else {
                                observedData.appProperties.titleFontColour = Color.black
                            }
                        })
                    Toggle("Text Shadow", isOn: $observedData.appProperties.titleFontShadow)
                        .toggleStyle(.switch)
                        //.disabled(observedData.args.bannerImage.value == "")
                        //.onChange(of: observedData.args.bannerImage.present, perform: { _ in
                        //    observedData.args.iconOption.present.toggle()
                        //})
                    Spacer()
                }
                HStack {
                    ColorPicker("ck-colour".localized,selection: $bannerColour)
                        .onChange(of: bannerColour, perform: { _ in
                            observedData.args.bannerImage.value = "color=\(bannerColour.hexValue)"
                            observedData.args.bannerImage.present = true
                        })
                    Button("ck-select".localized) {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes = [.image]
                        if panel.runModal() == .OK {
                            observedData.args.bannerImage.value = panel.url?.path ?? ""
                        }
                    }
                    Spacer()
                }
                HStack {
                    Text("Banner Height")
                        .frame(alignment: .leading)
                    TextField("", value: $bannerHeight, formatter: displayAsInt)
                        .frame(width: 50)
                    Slider(value: $bannerHeight, in: 28...250)
                        .onChange(of: bannerHeight, perform: { height in
                            observedData.args.bannerHeight.present = true
                            observedData.args.bannerHeight.value = "\(height.rounded())"
                        })
                }
                TextField("", text: $observedData.args.bannerImage.value)
            }
            /*
            VStack {
                Toggle("banner title", isOn: $observedData.args.bannerTitle.present)
                    .toggleStyle(.switch)
            }
             */
            HStack {
                Text("ck-watermark".localized)
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.watermarkImage.present)
                    .toggleStyle(.switch)
                    .disabled(observedData.args.watermarkImage.value == "")
                Button("ck-select".localized) {
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
                Picker("ck-fill".localized, selection: $observedData.args.watermarkFill.value) {
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
                Picker("ck-scale".localized, selection: $observedData.args.watermarkScale.value) {
                    Text("").tag("")
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                Picker("ck-positoin".localized, selection: $observedData.args.watermarkPosition.value) {
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
