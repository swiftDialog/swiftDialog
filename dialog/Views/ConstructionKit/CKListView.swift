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

    var body: some View {
        ScrollView {
            HStack {
                Button(action: {
                    observedData.listItemsArray.append(ListItems(title: "New Item"))
                    observedData.args.listItem.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Show".localized, isOn: $observedData.args.listItem.present)
                    .toggleStyle(.switch)

                Spacer()
            }

            ForEach($observedData.listItemsArray) { $item in
                VStack {
                    HStack {
                        CKIconPicker(
                            icon: $item.icon,
                            sfPicker: $item.sfPicker,
                            sfSymbol: $item.sfSymbol,
                            sfColour: $item.sfColour,
                            opacity: item.icon.isEmpty ? 0.5 : 1
                        )
                        TextField("Title".localized, text: $item.title)
                        TextField("Sub Title".localized, text: $item.subTitle)
                    }
                    HStack {
                        TextField("Status Text".localized, text: $item.statusText)
                        Picker("Status".localized, selection: $item.statusIcon) {
                            Text("").tag("")
                            ForEach(appDefaults.ckListStatusOptions, id: \.self) {
                                Text($0)
                            }
                        }
                        Slider(value: $item.progress, in: 0...100)
                        TextField("", value: $item.progress, formatter: displayAsInt)
                            .frame(width: 30)
                        Button(action: {
                            observedData.listItemsArray.removeAll { $0.id == item.id }
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
        // Single sync point to the canonical userInputState the list view renders from.
        .onChange(of: observedData.listItemsArray) { _, newValue in
            userInputState.listItems = newValue
        }
    }
}
