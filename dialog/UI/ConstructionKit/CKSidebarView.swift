//
//  CKIconView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKSidebarView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        VStack { // icon and icon overlay
            VStack {
                LabelView(label: "Icon")
                HStack {
                    Toggle("Visible", isOn: $observedData.args.iconOption.present)
                        .toggleStyle(.switch)
                    Toggle("Centred", isOn: $observedData.args.centreIcon.present)
                        .toggleStyle(.switch)
                    Button("Select")
                          {
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
                LabelView(label: "Icon Size")
                HStack {
                    Slider(value: $observedData.iconSize, in: 0...400)
                    //Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
                    TextField("Size value:", value: $observedData.iconSize, formatter: formatter)
                        .frame(width: 50)
                }
            }
            VStack {
                LabelView(label: "Overlay")
                HStack {
                    Toggle("Visible", isOn: $observedData.args.overlayIconOption.present)
                        .toggleStyle(.switch)
                    Button("Select")
                          {
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
            VStack {
                LabelView(label: "Infobox")
                HStack {
                    Toggle("Visible", isOn: $observedData.args.infoBox.present)
                        .toggleStyle(.switch)
                    TextEditor(text: $observedData.args.infoBox.value)
                        .frame(height: 50)
                        .background(Color("editorBackgroundColour"))
                }
            }
            VStack {
                LabelView(label: "Infotext")
                HStack {
                    Toggle("Visible", isOn: $observedData.args.infoText.present)
                        .toggleStyle(.switch)
                    TextField("Info Text", text: $observedData.args.infoText.value)
                }
            }
            
        }
        .padding(20)
        Spacer()
    }
}

