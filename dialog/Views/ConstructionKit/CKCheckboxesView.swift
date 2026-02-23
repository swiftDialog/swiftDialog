//
//  CKCheckboxes.swift
//  dialog
//
//  Created by Bart Reardon on 22/10/2025.
//

import SwiftUI

struct CKCheckBoxesView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    //@State var textfieldContent: [TextFieldState]
    @State private var showHelp: Bool = false
    @State private var tmpColour: Color = .clear

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
        //textfieldContent = userInputState.textFields
    }

    var body: some View {
        VStack {
        LabelView(label: "Checkboxes".localized)
        HStack {
            Toggle("Format output as JSON", isOn: $observedData.args.jsonOutPut.present)
            .toggleStyle(.switch)
            Spacer()
        }
        HStack {
            Button(action: {
                showHelp.toggle()
            }, label: {
                Image.init(systemName: "questionmark.app.fill")
            })
            .popover(isPresented: $showHelp) {
                let sdHelp = SDHelp(arguments: observedData.args)
                CKHelpView(text: sdHelp.argument.checkbox.helpLong)
            }
            
            
            Button(action: {
                userInputState.checkBoxes.append(CheckBoxes(label: "New Item"))
                observedData.observedUserInputState.checkBoxes.append(CheckBoxes(label: "New Item"))
                observedData.args.checkbox.present = true
                appArguments.checkbox.present = true
            }, label: {
                Image(systemName: "plus")
            })
            Toggle("Switch Style".localized, isOn: $observedData.args.checkboxStyle.present)
                .toggleStyle(.switch)
                .onChange(of: observedData.args.checkboxStyle.present) { _, style in
                    observedData.appProperties.checkboxControlStyle = style ? "switch" : ""
                }
            Toggle("Show".localized, isOn: $observedData.args.checkbox.present)
                .toggleStyle(.switch)
            
            //Button("Clear All") {
            //    observedData.listItemPresent = false
            //    observedData.listItemsArray = [ListItems]()
            //}
            
            Spacer()
        }
        .padding(.bottom, 20)
        
        
            ScrollView {
                //List {
                ForEach(0..<userInputState.checkBoxes.count, id: \.self) { item in
                    HStack {
                        
                        IconView(image: observedData.observedUserInputState.checkBoxes[item].icon, defaultImage: "sf=questionmark.square.dashed")
                            .frame(width: 32, height: 32)
                            .opacity(observedData.observedUserInputState.checkBoxes[item].icon.isEmpty || observedData.appProperties.checkboxControlStyle == "switch" ? 1 : 0.5)
                            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                                guard let provider = providers.first else { return false }
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    if let url = url {
                                        DispatchQueue.main.async {
                                            observedData.observedUserInputState.checkBoxes[item].icon = url.path
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
                            .onChange(of: observedData.observedUserInputState.checkBoxes[item].icon) { _, textRequired in
                                observedData.observedUserInputState.checkBoxes[item].icon = textRequired
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                observedData.observedUserInputState.checkBoxes[item].sfPicker.toggle()
                            }
                        
                            .popover(isPresented: $observedData.observedUserInputState.checkBoxes[item].sfPicker) {
                                VStack {
                                    HStack {
                                        Text("sf=")
                                        TextField("SF Symbol Name", text: $observedData.observedUserInputState.checkBoxes[item].sfSymbol)
                                            .onChange(of: observedData.observedUserInputState.checkBoxes[item].sfSymbol) { _, sfName in
                                                observedData.observedUserInputState.checkBoxes[item].icon = "sf=\(sfName)"
                                            }
                                    }
                                    ColorPicker("Colour".localized,selection: $tmpColour)
                                        .onChange(of: tmpColour) { _, colour in
                                            observedData.observedUserInputState.checkBoxes[item].sfColour = colour.hexValue
                                            observedData.observedUserInputState.checkBoxes[item].icon = "sf=\(observedData.observedUserInputState.checkBoxes[item].sfSymbol),color=\(colour.hexValue)"
                                        }
                                }
                                .padding(20)
                            }
                        
                        TextField("Label".localized, text: $observedData.observedUserInputState.checkBoxes[item].label)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[item].label) { _, label in
                                userInputState.checkBoxes[item].label = label
                                observedData.updateView.toggle()
                            }
                        TextField("Name".localized+": \(observedData.observedUserInputState.checkBoxes[item].name)", text: $observedData.observedUserInputState.checkBoxes[item].name)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[item].name) { _, name in
                                userInputState.checkBoxes[item].name = name
                                observedData.updateView.toggle()
                            }
                        Toggle("Checked".localized, isOn: $observedData.observedUserInputState.checkBoxes[item].checked)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[item].checked) { _, checked in
                                userInputState.checkBoxes[item].checked = checked
                                observedData.updateView.toggle()
                            }
                            .toggleStyle(.switch)
                        Toggle("Disabled".localized, isOn: $observedData.observedUserInputState.checkBoxes[item].disabled)
                            .onChange(of: observedData.observedUserInputState.checkBoxes[item].disabled) { _, disabled in
                                userInputState.checkBoxes[item].disabled = disabled
                                observedData.updateView.toggle()
                            }
                            .toggleStyle(.switch)
                        Button(action: {
                            guard item >= 0 && item < observedData.observedUserInputState.checkBoxes.count else {
                                writeLog("Could not delete checkbox at position \(item)", logLevel: .info)
                                return
                            }
                            writeLog("Delete checkbox at position \(item)", logLevel: .info)
                            userInputState.checkBoxes.remove(at: item)
                            observedData.observedUserInputState.checkBoxes.remove(at: item)
                            observedData.updateView.toggle()
                        }, label: {
                            Image(systemName: "trash")
                        })
                    }
                    Divider()
                }
            }
        }
        .padding(20)
    }
}

