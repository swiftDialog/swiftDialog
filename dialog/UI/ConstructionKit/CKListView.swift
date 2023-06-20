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
    
    let statusTypeArray = ["wait","success","fail","error","pending","progress"]
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    observedData.listItemsArray.append(ListItems(title: "", icon: "", statusText: "", statusIcon: "", progress: 0))
                    observedData.args.listItem.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("ck-show".localized, isOn: $observedData.args.listItem.present)
                    .toggleStyle(.switch)
                
                //Button("Clear All") {
                //    observedData.listItemPresent = false
                //    observedData.listItemsArray = [ListItems]()
                //}
                
                Spacer()
            }
            
            //ForEach(observedData.listItemsArray, id: \.self)
            
            ForEach(0..<observedData.listItemsArray.count, id: \.self) { item in
                HStack {
                    Button(action: {
                        //observedData.listItemsArray.remove(at: i)
                    }, label: {
                        Image(systemName: "trash")
                    })
                    .disabled(true) // MARK: disabled until I can work out how to delete from the array without causing a crash
                    TextField("ck-title".localized, text: $observedData.listItemsArray[item].title)
                    TextField("ck-statustext".localized, text: $observedData.listItemsArray[item].statusText)
                    Picker("ck-status".localized, selection: $observedData.listItemsArray[item].statusIcon) {
                        Text("").tag("")
                        ForEach(statusTypeArray, id: \.self) {
                            Text($0)
                        }
                    }
                    Slider(value: $observedData.listItemsArray[item].progress, in: 0...100)
                    TextField("", value: $observedData.listItemsArray[item].progress, formatter: displayAsInt)
                        .frame(width: 30)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

