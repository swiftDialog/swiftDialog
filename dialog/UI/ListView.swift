//
//  ListView.swift
//  dialog
//
//  Created by Bart Reardon on 27/1/2022.
//

import SwiftUI

struct ListView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        
        print(observedDialogContent.listItemArray.count)
        print(observedDialogContent.listItemArray)
        
        print(observedDialogContent.listItemStatus)
    }
    
    
    var body: some View {
        if cloptions.listItem.present {
            ScrollViewReader { proxy in
                //withAnimation(.default) {
                    VStack() {
                        Button("Jump to #10") {
                            proxy.scrollTo(10)
                        }
                        
                        List(0..<observedDialogContent.listItemArray.count, id: \.self) {i in
                            HStack {
                                Text(observedDialogContent.listItemArray[i])
                                    .font(.system(size: appvars.messageFontSize))
                                    .id(i)
                                Spacer()
                                Text(observedDialogContent.listItemStatus[i])
                                    .font(.system(size: appvars.messageFontSize))
                            }
                        }
                    }
                    .onChange(of: observedDialogContent.listItemUpdateRow, perform: { _ in
                        proxy.scrollTo(observedDialogContent.listItemUpdateRow)
                    })
                //}
            }
        }
    }
}


