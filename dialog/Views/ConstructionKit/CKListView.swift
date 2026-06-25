//
//  CKListView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKListView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    func removeItems(at offsets: IndexSet) {
        observedData.listItemsArray.remove(atOffsets: offsets)
    }

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

                Spacer()
            }

            ForEach(0..<observedData.listItemsArray.count, id: \.self) { item in
                VStack {
                    HStack {
                        CKIconPicker(
                            icon: $observedData.listItemsArray[item].icon,
                            sfPicker: $observedData.listItemsArray[item].sfPicker,
                            sfSymbol: $observedData.listItemsArray[item].sfSymbol,
                            sfColour: $observedData.listItemsArray[item].sfColour,
                            opacity: observedData.listItemsArray[item].icon.isEmpty ? 0.5 : 1,
                            onIconChange: { userInputState.listItems[item].icon = $0 }
                        )
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
                            ForEach(appDefaults.ckListStatusOptions, id: \.self) {
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

