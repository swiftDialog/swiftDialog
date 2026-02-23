//
//  CKListView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKListView: View {

    @ObservedObject var observedData: DialogUpdatableContent
    //@State private var showSFPicker: Bool = false
    @State private var tmpColour: Color = .clear

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    func removeItems(at offsets: IndexSet) {
        observedData.listItemsArray.remove(atOffsets: offsets)
    }

    let statusTypeArray = ["wait","success","fail","error","pending","progress"]

    var body: some View {
        ScrollView {
            HStack {
                Button(action: {
                    observedData.listItemsArray.append(ListItems(title: "New Item", icon: "", statusText: "", statusIcon: "", progress: 0))
                    userInputState.listItems.append(ListItems(title: "New Item", icon: "", statusText: "", statusIcon: "", progress: 0))
                    observedData.args.listItem.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Show".localized, isOn: $observedData.args.listItem.present)
                    .toggleStyle(.switch)

                //Button("Clear All") {
                //    observedData.listItemPresent = false
                //    observedData.listItemsArray = [ListItems]()
                //}

                Spacer()
            }

            //ForEach(observedData.listItemsArray, id: \.self)

            ForEach(0..<observedData.listItemsArray.count, id: \.self) { item in
                VStack {
                    HStack {
                        IconView(image: observedData.listItemsArray[item].icon, defaultImage: "sf=questionmark.square.dashed")
                            .frame(width: 32, height: 32)
                            .opacity(observedData.listItemsArray[item].icon.isEmpty ? 0.5 : 1)
                            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                                guard let provider = providers.first else { return false }
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    if let url = url {
                                        DispatchQueue.main.async {
                                            observedData.listItemsArray[item].icon = url.path
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
                            .onChange(of: observedData.listItemsArray[item].icon) { _, textRequired in
                                userInputState.listItems[item].icon = textRequired
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                observedData.listItemsArray[item].sfPicker.toggle()
                            }
                            .popover(isPresented: $observedData.listItemsArray[item].sfPicker) {
                                VStack {
                                    HStack {
                                        Text("sf=")
                                        TextField("SF Symbol Name", text: $observedData.listItemsArray[item].sfSymbol)
                                            .onChange(of: observedData.listItemsArray[item].sfSymbol) { _, sfName in
                                                observedData.listItemsArray[item].icon = "sf=\(sfName)"
                                            }
                                    }
                                    ColorPicker("Colour".localized,selection: $tmpColour)
                                        .onChange(of: tmpColour) { _, colour in
                                            observedData.listItemsArray[item].sfColour = colour.hexValue
                                            observedData.listItemsArray[item].icon = "sf=\(observedData.listItemsArray[item].sfSymbol),color=\(colour.hexValue)"
                                            
                                        }
                                    /*
                                    HStack {
                                        Text("Opacity")
                                        Slider(value: $observedData.listItemsArray[item].iconAlpha, in: 0...1)
                                            .onChange(of: observedData.listItemsArray[item].iconAlpha) { _, alpha in
                                                observedData.listItemsArray[item].iconAlpha = alpha
                                            }
                                    }
                                     */
                                }
                                .padding(20)
                            }
                        TextField("Title".localized, text: $observedData.listItemsArray[item].title)
                            .onChange(of: observedData.listItemsArray[item].title) { _, textRequired in
                                userInputState.listItems[item].title = textRequired
                            }
                        TextField("Sub Title".localized, text: $observedData.listItemsArray[item].subTitle)
                            .onChange(of: observedData.listItemsArray[item].subTitle) { _, textRequired in
                                userInputState.listItems[item].subTitle = textRequired
                            }
                    }
                    HStack {
                        TextField("Status Text".localized, text: $observedData.listItemsArray[item].statusText)
                            .onChange(of: observedData.listItemsArray[item].statusText) { _, textRequired in
                                userInputState.listItems[item].statusText = textRequired
                            }
                        Picker("Status".localized, selection: $observedData.listItemsArray[item].statusIcon) {
                            Text("").tag("")
                            ForEach(statusTypeArray, id: \.self) {
                                Text($0)
                            }
                            .onChange(of: observedData.listItemsArray[item].statusIcon) { _, textRequired in
                                userInputState.listItems[item].statusIcon = textRequired
                            }
                        }
                        Slider(value: $observedData.listItemsArray[item].progress, in: 0...100)
                            .onChange(of: observedData.listItemsArray[item].progress) { _, textRequired in
                                userInputState.listItems[item].progress = textRequired
                            }
                        TextField("", value: $observedData.listItemsArray[item].progress, formatter: displayAsInt)
                            .frame(width: 30)
                        Button(action: {
                            observedData.listItemsArray.remove(at: item)
                            userInputState.listItems.remove(at: item)
                        }, label: {
                            Image(systemName: "trash")
                        })
                    }
                    Divider()
                        .padding(20)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

