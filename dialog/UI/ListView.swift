//
//  ListView.swift
//  dialog
//
//  Created by Bart Reardon on 27/1/2022.
//

import SwiftUI

struct StatusImage: View {
    
    var name: String
    var colour: Color
    
    init(name: String, colour: Color) {
        self.name = name
        self.colour = colour
    }
    
    var body: some View {
        Image(systemName: name)
            .resizable()
            .foregroundColor(colour)
            .scaledToFit()
            .frame(height: 23)
    }
}

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
                            VStack {
                                HStack {
                                    Text(observedDialogContent.listItemArray[i])
                                        .font(.system(size: appvars.messageFontSize))
                                        .id(i)
                                    Spacer()
                                    switch observedDialogContent.listItemStatus[i] {
                                    case "wait" :
                                        ProgressView()
                                            .frame(height: 10)
                                    case "success" :
                                        StatusImage(name: "checkmark.circle.fill", colour: .green)
                                    case "fail" :
                                        StatusImage(name: "xmark.circle.fill", colour: .red)
                                    case "pending" :
                                        StatusImage(name: "ellipsis.circle.fill", colour: .gray)
                                    case "error" :
                                        StatusImage(name: "exclamationmark.circle.fill", colour: .yellow)
                                    default:
                                        Text(observedDialogContent.listItemStatus[i])
                                        .font(.system(size: appvars.messageFontSize))
                                        .animation(.easeInOut(duration: 0.1))
                                    }
                                    /*
                                    if observedDialogContent.listItemStatus[i] == "wait" {
                                        ProgressView()
                                            .frame(height: 20)
                                    } else {
                                        Text(observedDialogContent.listItemStatus[i])
                                        .font(.system(size: appvars.messageFontSize))
                                        .animation(.easeInOut(duration: 0.1))
                                    }
                                     */
                                }
                                .padding(.top, 5)
                                .padding(.bottom, 5)
                                //if ( i < observedDialogContent.listItemArray.count-1 ) {
                                    Divider()
                                //}
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                //}
            }
        }
    }
}


