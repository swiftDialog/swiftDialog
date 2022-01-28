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
    }
    
    
    var body: some View {
        if observedDialogContent.listItemPresent {
            ScrollViewReader { proxy in
                //withAnimation(.default) {
                    VStack() {                        
                        List(0..<observedDialogContent.listItemArray.count, id: \.self) {i in
                            HStack {
                                Text(observedDialogContent.listItemArray[i])
                                    .font(.system(size: appvars.messageFontSize))
                                    .id(i)
                                Spacer()
                                Text(observedDialogContent.listItemStatus[i])
                                    .font(.system(size: appvars.messageFontSize))
                                    .animation(.easeInOut(duration: 0.1))
                            }
                        }
                    }
                    .onChange(of: observedDialogContent.listItemUpdateRow, perform: { _ in
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(observedDialogContent.listItemUpdateRow)
                            }
                        }
                    })
                //}
            }
        }
    }
}


