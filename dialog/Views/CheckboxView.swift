//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct RenderToggles: View {
    @ObservedObject var observedData: DialogUpdatableContent

    var iconPresent: Bool = false
    var rowHeight: CGFloat = 10

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        if observedData.appProperties.checkboxControlSize == .large {
            rowHeight = observedData.appProperties.messageFontSize + 24
        } else {
            rowHeight = observedData.appProperties.messageFontSize + 14
        }

        iconPresent = observedData.appProperties.checkboxArray.contains { $0.icon != "" }
        if iconPresent {
            writeLog("One or more switches have an acssociated icon")
        }
    }

    var body: some View {
        VStack {
            ForEach(0..<observedData.appProperties.checkboxArray.count, id: \.self) {index in
                HStack {
                    if observedData.appProperties.checkboxControlStyle == "switch" {
                        let _ = writeLog("Displaying switches instead of checkboxes")
                        if iconPresent {
                            if observedData.appProperties.checkboxArray[index].icon != "" {
                                let _ = writeLog("Switch index \(index): Displaying icon \(observedData.appProperties.checkboxArray[index].icon)")
                                IconView(image: observedData.appProperties.checkboxArray[index].icon, overlay: "")
                                    .frame(height: rowHeight)
                            } else {
                                let _ = writeLog("Switch index \(index) has no icon")
                                IconView(image: "none", overlay: "")
                                    .frame(height: rowHeight)
                            }
                        }
                        Text(observedData.appProperties.checkboxArray[index].label)
                        Spacer()
                        Toggle("", isOn: $observedData.appProperties.checkboxArray[index].checked)
                            .toggleStyle(.switch)
                            .disabled(observedData.appProperties.checkboxArray[index].disabled)
                            .controlSize(observedData.appProperties.checkboxControlSize)
                    } else {
                        Toggle(observedData.appProperties.checkboxArray[index].label, isOn: $observedData.appProperties.checkboxArray[index].checked)
                            .toggleStyle(.checkbox)
                            .onChange(of: observedData.appProperties.checkboxArray[index].checked) { checked in
                                if observedData.appProperties.checkboxArray[index].enablesButton1 {
                                    observedData.args.button1Disabled.present = !checked
                                }
                            }
                            .disabled(observedData.appProperties.checkboxArray[index].disabled)
                        Spacer()
                    }
                }
                .frame(alignment: .center)
                .frame(width: .infinity)

                // Horozontal Line
                if index < observedData.appProperties.checkboxArray.count-1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .font(.system(size: observedData.appProperties.labelFontSize))
        .padding(10)
        .background(Color.background.opacity(0.5))
        .cornerRadius(8)
    }
}

struct CheckboxView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    var toggleStyle: any ToggleStyle = .checkbox

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

    }

    var body: some View {
        if observedData.args.checkbox.present {
            if observedData.appProperties.checkboxControlStyle.lowercased() == "switch" {
                VStack {
                    Spacer()
                    RenderToggles(observedDialogContent: observedData)
                }
                .scrollOnOverflow()
            } else {
                RenderToggles(observedDialogContent: observedData)
            }
        }
    }
}


