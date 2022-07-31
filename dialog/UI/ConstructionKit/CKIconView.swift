//
//  CKIconView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKIconView: View {
    
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
                    TextField("Size value:", value: $observedData.iconSize, formatter: NumberFormatter())
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
        }
        .padding(20)
        Spacer()
    }
}

