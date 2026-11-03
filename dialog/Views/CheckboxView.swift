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

    /// Only draw these checkboxes (nil = all). Used when `vieworder` places inputs individually.
    var indices: [Int]?
    /// Drawn inside a group, which supplies the surrounding box and dividers
    var embedded: Bool = false

    init(observedDialogContent: DialogUpdatableContent, indices: [Int]? = nil, embedded: Bool = false) {
        self.observedData = observedDialogContent
        self.indices = indices
        self.embedded = embedded
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
        // Guard against array size mismatch during card transitions
        let checkboxCount = observedData.observedUserInputState.checkBoxes.count
        if checkboxCount > 0 && checkboxCount == userInputState.checkBoxes.count {
            VStack {
                ForEach(indices?.filter { $0 < checkboxCount } ?? Array(0..<checkboxCount), id: \.self) {index in
                    Group {
                    HStack {
                        if observedData.appProperties.checkboxControlStyle == "switch" {
                        let _ = writeLog("Displaying switches instead of checkboxes", logLevel: .debug)
                        if iconPresent {
                            if observedData.observedUserInputState.checkBoxes[index].icon != "" {
                                let _ = writeLog("Switch index \(index): Displaying icon \(observedData.observedUserInputState.checkBoxes[index].icon)", logLevel: .debug)
                                IconView(image: observedData.observedUserInputState.checkBoxes[index].icon, overlay: "")
                                    .frame(height: rowHeight)
                            } else {
                                let _ = writeLog("Switch index \(index) has no icon", logLevel: .debug)
                                IconView(image: "none", overlay: "")
                                    .frame(height: rowHeight)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(observedData.observedUserInputState.checkBoxes[index].label)
                            DetailText(observedData.observedUserInputState.checkBoxes[index].detail)
                        }
                        Spacer()
                        Toggle("", isOn: boundedBinding($observedData.observedUserInputState.checkBoxes, index, \.checked, default: false))
                            .toggleStyle(.switch)
                            .disabled(observedData.observedUserInputState.checkBoxes[index].disabled)
                            .controlSize(observedData.appProperties.checkboxControlSize)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[index].checked) { _, checked in
                                setIfInBounds(&userInputState.checkBoxes, index, \.checked, checked)
                            }
                    } else {
                        Toggle(isOn: boundedBinding($observedData.observedUserInputState.checkBoxes, index, \.checked, default: false)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(observedData.observedUserInputState.checkBoxes[index].label)
                                DetailText(observedData.observedUserInputState.checkBoxes[index].detail)
                            }
                                .padding(.leading, 5)
                        }
                            .toggleStyle(.checkbox)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[index].checked) { _, checked in
                                setIfInBounds(&userInputState.checkBoxes, index, \.checked, checked)
                                guard observedData.observedUserInputState.checkBoxes.indices.contains(index) else { return }
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
                if !embedded && index < observedData.observedUserInputState.checkBoxes.count-1 {
                    Divider().opacity(0.5)
                }
                }
                .controlDependencies(observedData, enabledIf: observedData.observedUserInputState.checkBoxes[index].enabledIf,
                                     visibleIf: observedData.observedUserInputState.checkBoxes[index].visibleIf)
            }
            }
            .font(.system(size: observedData.appProperties.labelFontSize))
            .inputBox(embedded: embedded)
        }
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
            if cardState.isNavigationStyle {
                // Navigation style: the page scrolls, so render at natural height. The
                // overflow wrapper's GeometryReader collapses inside the page's ScrollView.
                RenderToggles(observedDialogContent: observedData)
            } else if observedData.appProperties.checkboxControlStyle.lowercased() == "switch" {
                VStack {
                    //Spacer()
                    RenderToggles(observedDialogContent: observedData)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newValue in
                            switchHeight = newValue
                        }
                        .scrollOnOverflow()
                }
                .frame(minHeight: 10, maxHeight: switchHeight)
            } else {
                RenderToggles(observedDialogContent: observedData)
            }
        }
    }
}


