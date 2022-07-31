//
//  CKImageView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKImageView: View {
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    observedData.imageArray.append(MainImage(path: ""))
                    observedData.args.mainImage.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Show", isOn: $observedData.args.mainImage.present)
                    .toggleStyle(.switch)
                Toggle("AutoPlay", isOn: $observedData.args.autoPlay.present)
                    .toggleStyle(.switch)
                TextField("Autoplay Seconds", text: $observedData.args.autoPlay.value)
                Spacer()
            }
            
            //ForEach(observedData.listItemsArray, id: \.self)
            
            ForEach(0..<observedData.imageArray.count, id: \.self) { item in
                HStack {
                    Button(action: {
                        //observedData.listItemsArray.remove(at: i)
                    }, label: {
                        Image(systemName: "trash")
                    })
                    .disabled(true) // MARK: disabled until I can work out how to delete from the array without causing a crash
                    Button("Select")
                          {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.allowedContentTypes = [.image]
                            if panel.runModal() == .OK {
                                observedData.imageArray[item].path = panel.url?.path ?? "<none>"
                            }
                          }
                    TextField("Path", text: $observedData.imageArray[item].path)
                    TextField("Caption", text: $observedData.imageArray[item].caption)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}
