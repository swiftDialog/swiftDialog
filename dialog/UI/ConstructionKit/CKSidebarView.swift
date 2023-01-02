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
                LabelView(label: "ck-icon".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.iconOption.present)
                        .toggleStyle(.switch)
                    Toggle("ck-centred".localized, isOn: $observedData.args.centreIcon.present)
                        .toggleStyle(.switch)
                    Button("ck-select".localized)
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
                LabelView(label: "ck-iconsize".localized)
                HStack {
                    Slider(value: $observedData.iconSize, in: 0...400)
                    //Text("Current value: \(observedDialogContent.iconSize, specifier: "%.0f")")
                    TextField("Size value:", value: $observedData.iconSize, formatter: formatter)
                        .frame(width: 50)
                }
            }
            VStack {
                LabelView(label: "ck-overlay".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.overlayIconOption.present)
                        .toggleStyle(.switch)
                    Button("ck-select".localized)
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
                LabelView(label: "ck-infobox".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.infoBox.present)
                        .toggleStyle(.switch)
                    TextEditor(text: $observedData.args.infoBox.value)
                        .frame(height: 100)
                        .background(Color("editorBackgroundColour"))
                }
            }
            VStack {
                LabelView(label: "ck-infotext".localized)
                HStack {
                    Toggle("ck-visible".localized, isOn: $observedData.args.infoText.present)
                        .toggleStyle(.switch)
                    TextField("ck-infotext".localized, text: $observedData.args.infoText.value)
                }
            }
            
        }
        .padding(20)
        Spacer()
    }
}

