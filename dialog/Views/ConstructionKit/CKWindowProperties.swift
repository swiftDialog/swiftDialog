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

        ScrollView {
            LabelView(label: "Window Height".localized)
            HStack {
                TextField("Height value:".localized, value: $observedData.appProperties.windowHeight, formatter: displayAsInt )
                    .frame(width: 50)
                Slider(value: $observedData.appProperties.windowHeight, in: 200...2000)
                    .frame(width: 200)
                    .onChange(of: observedData.appProperties.windowHeight) { _, height in
                        observedData.appProperties.windowHeight = height.rounded()
                    }
                Spacer()
            }
            LabelView(label: "Window Width".localized)
            HStack {
                TextField("Width value:".localized, value: $observedData.appProperties.windowWidth, formatter: displayAsInt)
                    .frame(width: 50)
                Slider(value: $observedData.appProperties.windowWidth, in: 200...2000)
                    .frame(width: 200)
                    .onChange(of: observedData.appProperties.windowWidth) { _, width in
                        observedData.appProperties.windowWidth = width.rounded()
                    }
                Spacer()
            }
            Group {
                LabelView(label: "Window Properties".localized)
                //HStack {
                //    Text("Mini view")
                //        .frame(width: 100, alignment: .leading)
                //    Toggle("", isOn: $observedData.args.miniMode.present)
                //        .toggleStyle(.switch)
                //    Spacer()
                //}
                HStack {
                    Text("Preset Sizes".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("Small".localized, isOn: $observedData.args.smallWindow.present)
                        .toggleStyle(.switch)
                        .onChange(of: observedData.args.smallWindow.present) {
                            observedData.appProperties.scaleFactor = 0.75
                            observedData.iconSize = 120
                            if observedData.args.smallWindow.present {
                                observedData.args.bigWindow.present = false
                            }
                        }
                    Toggle("Big".localized, isOn: $observedData.args.bigWindow.present)
                        .toggleStyle(.switch)
                        .onChange(of: observedData.args.bigWindow.present) {
                            observedData.appProperties.scaleFactor = 1.25
                            if observedData.args.bigWindow.present {
                                observedData.args.smallWindow.present = false
                            }
                        }
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
                    Text("Screen Background Blur".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.blurScreen.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("Movable".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.movableWindow.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                HStack {
                    Text("Force on Top".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.forceOnTop.present)
                        .toggleStyle(.switch)
                    Spacer()
                }
                LabelView(label: "Progress Bar")
                HStack {
                    Text("Progress Bar".localized)
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $observedData.args.progressBar.present)
                        .toggleStyle(.switch)
                    TextField("Progress value:".localized, value: $observedData.args.progressBar.value, formatter: displayAsInt)
                        .frame(width: 50)
                    TextField("Progress Text:".localized, text: $observedData.args.progressText.value)
                        .frame(width: 150)
                        .onChange(of: observedData.args.progressText.value) {
                            observedData.args.progressText.present = true
                        }
                    Spacer()
                }
            }
            
            /*
            VStack {
                Toggle("banner title", isOn: $observedData.args.bannerTitle.present)
                    .toggleStyle(.switch)
            }
             */
            LabelView(label: "Background Image".localized)
            IconView(image: observedData.args.watermarkImage.value)
                .frame(width: 48, height: 48)
                .opacity(observedData.args.watermarkImage.present ? 1 : 0.5)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                observedData.args.watermarkImage.value = url.path
                                observedData.args.watermarkImage.present = true
                            }
                        }
                    }
                    return true
                }
                .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.gray.opacity(0.5))
                    )
            HStack {
                Text("Watermark".localized)
                    .frame(width: 100, alignment: .leading)
                Toggle("", isOn: $observedData.args.watermarkImage.present)
                    .toggleStyle(.switch)
                    .disabled(observedData.args.watermarkImage.value == "")
                Button("Select".localized) {
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
                Picker("Fill".localized, selection: $observedData.args.watermarkFill.value) {
                    Text("").tag("")
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                HStack {
                    Text("Opacity".localized)
                    Slider(value: $bgAlpha, in: 0.0...1.0, step: 0.1)
                        .onChange(of: bgAlpha) {
                            observedData.args.watermarkAlpha.value = String(format: "%.1f", bgAlpha)
                        }
                }
                Picker("Scale".localized, selection: $observedData.args.watermarkScale.value) {
                    Text("").tag("")
                    ForEach(fillScaleArray, id: \.self) {
                        Text($0)
                    }
                }
                Picker("Position".localized, selection: $observedData.args.watermarkPosition.value) {
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
