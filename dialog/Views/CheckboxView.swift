//
//  CheckboxView.swift
//  dialog
//
//  Created by Bart Reardon on 23/1/2022.
//

import SwiftUI

struct RenderToggles: View {
    @ObservedObject var observedData: DialogUpdatableContent
    //@State var checkboxContent: [CheckBoxes]

    var iconPresent: Bool = false
    var rowHeight: CGFloat = 10

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        //self.checkboxContent = checkboxContent
        if observedData.appProperties.checkboxControlSize == .large {
            rowHeight = observedData.appProperties.messageFontSize + 24
        } else {
            rowHeight = observedData.appProperties.messageFontSize + 14
        }

        iconPresent = observedDialogContent.observedUserInputState.checkBoxes.contains { $0.icon != "" }
        if iconPresent {
            writeLog("One or more switches have an acssociated icon")
        }
    }

    var body: some View {
        VStack {
            ForEach(0..<observedData.observedUserInputState.checkBoxes.count, id: \.self) {index in
                HStack {
                    if observedData.appProperties.checkboxControlStyle == "switch" {
                        let _ = writeLog("Displaying switches instead of checkboxes")
                        if iconPresent {
                            if observedData.observedUserInputState.checkBoxes[index].icon != "" {
                                let _ = writeLog("Switch index \(index): Displaying icon \(observedData.observedUserInputState.checkBoxes[index].icon)")
                                IconView(image: observedData.observedUserInputState.checkBoxes[index].icon, overlay: "")
                                    .frame(height: rowHeight)
                            } else {
                                let _ = writeLog("Switch index \(index) has no icon")
                                IconView(image: "none", overlay: "")
                                    .frame(height: rowHeight)
                            }
                        }
                        Text(observedData.observedUserInputState.checkBoxes[index].label)
                        Spacer()
                        Toggle("", isOn: $observedData.observedUserInputState.checkBoxes[index].checked)
                            .toggleStyle(.switch)
                            .disabled(observedData.observedUserInputState.checkBoxes[index].disabled)
                            .controlSize(observedData.appProperties.checkboxControlSize)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[index].checked) { _, checked in
                                userInputState.checkBoxes[index].checked = checked
                            }
                    } else {
                        Toggle(isOn: $observedData.observedUserInputState.checkBoxes[index].checked) {
                            Text(observedData.observedUserInputState.checkBoxes[index].label)
                                .padding(.leading, 5)
                        }
                            .toggleStyle(.checkbox)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[index].checked) { _, checked in
                                userInputState.checkBoxes[index].checked = checked
                                if observedData.observedUserInputState.checkBoxes[index].enablesButton1 {
                                    observedData.args.button1Disabled.present = !checked
                                }
                            }
                            .disabled(observedData.observedUserInputState.checkBoxes[index].disabled)
                        Spacer()
                    }
                }
                .frame(alignment: .center)
                .frame(width: .infinity)

                // Horozontal Line
                if index < observedData.observedUserInputState.checkBoxes.count-1 {
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
                    RenderToggles(observedDialogContent: observedData)
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
                RenderToggles(observedDialogContent: observedData)
            }
        }
    }
}


