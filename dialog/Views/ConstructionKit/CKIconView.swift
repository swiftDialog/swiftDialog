//
//  CKIconView.swift
//  dialog
//
//  Created by Bart Reardon on 20/10/2025.
//

import SwiftUI

struct CKIconView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        ScrollView { // icon and icon overlay
            VStack {
                LabelView(label: "Icon".localized)
                HStack {
                    IconView(image: observedData.args.iconOption.value, defaultImage: "sf=questionmark.square.dashed")
                        .frame(width: 48, height: 48)
                        .opacity(observedData.args.iconOption.present ? 1 : 0.5)
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            guard let provider = providers.first else { return false }
                            
                            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        observedData.args.iconOption.value = url.path
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
                    
                    Toggle("Visible".localized, isOn: $observedData.args.iconOption.present)
                        .toggleStyle(.switch)
                    Toggle("Centred".localized, isOn: $observedData.args.centreIcon.present)
                        .toggleStyle(.switch)
                    Button("Select".localized) {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.allowedContentTypes = [.image, .application, .systemPreferencesPane]
                            if panel.runModal() == .OK {
                                observedData.args.iconOption.value = panel.url?.path ?? "<none>"
                            }
                          }
                    TextField("", text: $observedData.args.iconOption.value)
                }
                HStack {
                    Button(action: {
                        observedData.args.iconOption.value = "SF=\(observedData.args.iconOption.value)"
                    }, label: {
                        Text("SF Symbol")
                    })
                    Spacer()
                }
                LabelView(label: "Icon Size".localized)
                HStack {
                    Slider(value: $observedData.iconSize, in: 0...400)
                    //Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
                    TextField("Size value:", value: $observedData.iconSize, formatter: displayAsInt)
                        .frame(width: 50)
                }
                LabelView(label: "Icon Alpha")
                HStack {
                    Slider(value: $observedData.iconAlpha, in: 0.0...1.0)
                    TextField("Alpha value:", value: $observedData.iconAlpha,
                              formatter: displayAsDouble)
                        .frame(width: 50)
                }
            }
            VStack {
                LabelView(label: "Overlay".localized)
                HStack {
                    Toggle("Visible".localized, isOn: $observedData.args.overlayIconOption.present)
                        .toggleStyle(.switch)
                    Button("Select".localized) {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.allowedContentTypes = [.image]
                            if panel.runModal() == .OK {
                                observedData.args.overlayIconOption.value = panel.url?.path ?? "<none>"
                            }
                          }
                    TextField("", text: $observedData.args.overlayIconOption.value)
                }
            }
        }
        .padding(20)
        Spacer()
    }
}

