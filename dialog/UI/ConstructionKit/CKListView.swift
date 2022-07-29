//
//  CKListView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKListView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    let statusTypeArray = ["wait","success","fail","error","pending","progress"]
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    observedData.listItemsArray.append(ListItems(title: "", icon: "", statusText: "", statusIcon: "", progress: 0))
                    observedData.listItemPresent = true
                }, label: {
                    Image(systemName: "plus.square")
                })
                Toggle("Show", isOn: $observedData.listItemPresent)
                    .toggleStyle(.switch)
                /*
                Button("Clear All") {
                    observedData.listItemPresent = false
                    observedData.listItemsArray = [ListItems]()
                }
                 */
                Spacer()
            }
            //List(0..<observedData.listItemsArray.count, id: \.self) {i in
            
            ForEach(0..<observedData.listItemsArray.count, id: \.self) {i in
                HStack {
                    /*
                    Button(action: {
                        observedData.listItemsArray.remove(at: i)
                    }, label: {
                        Image(systemName: "trash")
                    })
                     */
                    TextField("Title", text: $observedData.listItemsArray[i].title)
                    TextField("Status Text", text: $observedData.listItemsArray[i].statusText)
                    Picker("Status", selection: $observedData.listItemsArray[i].statusIcon)
                    {
                        ForEach(statusTypeArray, id: \.self) {
                            Text($0)
                        }
                    }
                    Slider(value: $observedData.listItemsArray[i].progress, in: 0...100)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

