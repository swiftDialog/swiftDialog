//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct RenderToggles: View {
    @ObservedObject var observedData: DialogUpdatableContent
    @State var checkboxContent: [CheckBoxes]

    var iconPresent: Bool = false
    var rowHeight: CGFloat = 10

    init(observedDialogContent: DialogUpdatableContent, checkboxContent: [CheckBoxes]) {
        self.observedData = observedDialogContent
        self.checkboxContent = checkboxContent
        if observedData.appProperties.checkboxControlSize == .large {
            rowHeight = observedData.appProperties.messageFontSize + 24
        } else {
            rowHeight = observedData.appProperties.messageFontSize + 14
        }

        iconPresent = checkboxContent.contains { $0.icon != "" }
        if iconPresent {
            writeLog("One or more switches have an acssociated icon")
        }
    }

    var body: some View {
        VStack {
            ForEach(0..<checkboxContent.count, id: \.self) {index in
                HStack {
                    if observedData.appProperties.checkboxControlStyle == "switch" {
                        let _ = writeLog("Displaying switches instead of checkboxes")
                        if iconPresent {
                            if checkboxContent[index].icon != "" {
                                let _ = writeLog("Switch index \(index): Displaying icon \(checkboxContent[index].icon)")
                                IconView(image: checkboxContent[index].icon, overlay: "")
                                    .frame(height: rowHeight)
                            } else {
                                let _ = writeLog("Switch index \(index) has no icon")
                                IconView(image: "none", overlay: "")
                                    .frame(height: rowHeight)
                            }
                        }
                        Text(checkboxContent[index].label)
                        Spacer()
                        Toggle("", isOn: $checkboxContent[index].checked)
                            .toggleStyle(.switch)
                            .disabled(checkboxContent[index].disabled)
                            .controlSize(observedData.appProperties.checkboxControlSize)
                            .onChange(of: checkboxContent[index].checked) {
                                userInputState.checkBoxes[index].checked = checkboxContent[index].checked
                            }
                    } else {
                        Toggle(checkboxContent[index].label, isOn: $checkboxContent[index].checked)
                            .toggleStyle(.checkbox)
                            .onChange(of: checkboxContent[index].checked) {
                                userInputState.checkBoxes[index].checked = checkboxContent[index].checked
                                if checkboxContent[index].enablesButton1 {
                                    observedData.args.button1Disabled.present = !checkboxContent[index].checked
                                }
                            }
                            .disabled(checkboxContent[index].disabled)
                        Spacer()
                    }
                }
                .frame(alignment: .center)
                .frame(width: .infinity)

                // Horozontal Line
                if index < checkboxContent.count-1 {
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
    @State private var switchHeight: CGFloat = 30

    var toggleStyle: any ToggleStyle = .checkbox

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

    }

    var body: some View {
        if observedData.args.checkbox.present {
            if observedData.appProperties.checkboxControlStyle.lowercased() == "switch" {
                VStack {
                    //Spacer()
                    RenderToggles(observedDialogContent: observedData, checkboxContent: userInputState.checkBoxes)
                        .background(GeometryReader {child -> Color in
                            DispatchQueue.main.async {
                                // update on next cycle with calculated height
                                self.switchHeight = child.size.height
                            }
                            return Color.clear
                        })
                        .scrollOnOverflow()
                }
                .frame(minHeight: 10, maxHeight: switchHeight)
            } else {
                RenderToggles(observedDialogContent: observedData, checkboxContent: userInputState.checkBoxes)
            }
        }
    }
}


