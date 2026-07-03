//
//  CKIconView.swift
//  dialog
//
//  Created by Bart Reardon on 20/10/2025.
//

import SwiftUI

struct CKIconView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    // Local state for the shared icon picker's SF Symbol popover (the icon args
    // only store the composed icon string).
    @State private var iconSfPicker = false
    @State private var iconSfSymbol = ""
    @State private var iconSfColour = ""
    @State private var overlaySfPicker = false
    @State private var overlaySfSymbol = ""
    @State private var overlaySfColour = ""

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        ScrollView { // icon and icon overlay
            VStack {
                CKLabelView(label: "Icon".localized)
                HStack {
                    CKIconPicker(icon: $observedData.args.iconOption.value,
                                 sfPicker: $iconSfPicker,
                                 sfSymbol: $iconSfSymbol,
                                 sfColour: $iconSfColour,
                                 opacity: observedData.args.iconOption.present ? 1 : 0.5)

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
                CKLabelView(label: "Icon Size".localized)
                HStack {
                    Slider(value: $observedData.iconSize, in: 0...400)
                    TextField("Size value:", value: $observedData.iconSize, formatter: displayAsInt)
                        .frame(width: 50)
                }
                CKLabelView(label: "Icon Alpha")
                HStack {
                    Slider(value: $observedData.iconAlpha, in: 0.0...1.0)
                    TextField("Alpha value:", value: $observedData.iconAlpha,
                              formatter: displayAsDouble)
                        .frame(width: 50)
                }
            }
            VStack {
                CKLabelView(label: "Overlay".localized)
                HStack {
                    CKIconPicker(icon: $observedData.args.overlayIconOption.value,
                                 sfPicker: $overlaySfPicker,
                                 sfSymbol: $overlaySfSymbol,
                                 sfColour: $overlaySfColour,
                                 opacity: observedData.args.overlayIconOption.present ? 1 : 0.5)

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
