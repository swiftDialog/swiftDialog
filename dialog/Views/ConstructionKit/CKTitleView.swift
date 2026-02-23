//
//  CKBasicsView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKTitleView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State var bannerColour: Color = .white
    @State var bannerHeight: CGFloat = 150
    
    let alignmentArray = ["left", "centre", "right"]

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {

        ScrollView {
            LabelView(label: "Title".localized)
            HStack {
                TextField("", text: $observedData.args.titleOption.value)
                ColorPicker("Colour".localized,selection: $observedData.appProperties.titleFontColour)
                Button("Reset".localized) {
                    observedData.appProperties.titleFontColour = .primary
                }
            }
            HStack {
                Text("Font Size: ".localized)
                Slider(value: $observedData.appProperties.titleFontSize, in: 10...80)
                TextField("value:".localized, value: $observedData.appProperties.titleFontSize, formatter: NumberFormatter())
                    .frame(width: 50)
            }
            
            Group {
                LabelView(label: "Banner Image".localized)
                IconView(image: observedData.args.bannerImage.value)
                    .frame(width: 200, height: 48)
                    .opacity(observedData.args.bannerImage.present ? 1 : 0.5)
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                DispatchQueue.main.async {
                                    observedData.args.bannerImage.value = url.path
                                    observedData.args.bannerImage.present = true
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
                    Toggle("Enabled", isOn: $observedData.args.bannerImage.present)
                        .toggleStyle(.switch)
                        .disabled(observedData.args.bannerImage.value == "")
                        .onChange(of: observedData.args.bannerImage.present) { _, isEnabled in
                            observedData.args.iconOption.present.toggle()
                            observedData.args.bannerTitle.present = isEnabled
                        }
                    Toggle("Banner Title", isOn: $observedData.args.bannerTitle.present)
                        .toggleStyle(.switch)
                        //.disabled(observedData.args.bannerImage.value == "")
                        .onChange(of: observedData.args.bannerTitle.present) { _, isEnabled in
                            if isEnabled {
                                observedData.appProperties.titleFontColour = Color.white
                            } else {
                                observedData.appProperties.titleFontColour = Color.black
                            }
                        }
                    Toggle("Text Shadow", isOn: $observedData.appProperties.titleFontShadow)
                        .toggleStyle(.switch)
                        //.disabled(observedData.args.bannerImage.value == "")
                        //.onChange(of: observedData.args.bannerImage.present, perform: { _ in
                        //    observedData.args.iconOption.present.toggle()
                        //})
                    Spacer()
                }
                HStack {
                    ColorPicker("Colour".localized,selection: $bannerColour)
                        .onChange(of: bannerColour) {
                            observedData.args.bannerImage.value = "color=\(bannerColour.hexValue)"
                            observedData.args.bannerImage.present = true
                        }
                    Button("Select".localized) {
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
                        .onChange(of: bannerHeight) { _, height in
                            observedData.args.bannerHeight.present = true
                            observedData.args.bannerHeight.value = "\(height.rounded())"
                        }
                }
                TextField("", text: $observedData.args.bannerImage.value)
            }
        }
        .padding(20)

    }
}

