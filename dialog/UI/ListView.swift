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
            .frame(width: 25, height: 25)
            //.border(.red)
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
                        List(0..<observedDialogContent.listItemsArray.count, id: \.self) {i in
                            VStack {
                                HStack {
                                    Text(observedDialogContent.listItemsArray[i].title)
                                        .font(.system(size: appvars.messageFontSize))
                                        .id(i)
                                    Spacer()
                                    if observedDialogContent.listItemsArray[i].statusText != "" {
                                        Text(observedDialogContent.listItemsArray[i].statusText)
                                            .font(.system(size: appvars.messageFontSize))
                                    }
                                    switch observedDialogContent.listItemsArray[i].statusIcon {
                                    case "wait" :
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.8, anchor: .trailing)
                                            .frame(height: 25)
                                    case "success" :
                                        StatusImage(name: "checkmark.circle.fill", colour: .green)
                                    case "fail" :
                                        StatusImage(name: "xmark.circle.fill", colour: .red)
                                    case "pending" :
                                        StatusImage(name: "ellipsis.circle.fill", colour: .gray)
                                    case "error" :
                                        StatusImage(name: "exclamationmark.circle.fill", colour: .yellow)
                                    default:
                                        Text(observedDialogContent.listItemsArray[i].statusIcon)
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
                                .frame(height: 34)
                                //.padding(.top, 5)
                                //.padding(.bottom, 5)
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


public struct CircularProgressViewStyle: ProgressViewStyle {
    var size: CGFloat
    private let lineWidth: CGFloat = 3
    private let defaultProgress = 0.0
    private let gradient = LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
    
    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        ZStack {
            configuration.label
            progressCircleView(fractionCompleted: configuration.fractionCompleted ?? defaultProgress)
            configuration.currentValueLabel
        }
    }
    
    private func progressCircleView(fractionCompleted: Double) -> some View {
        Circle()
            .stroke(gradient, lineWidth: lineWidth)
            .opacity(0.2)
            .overlay(progressFill(fractionCompleted: fractionCompleted))
            .frame(width: size, height: size)
    }
    
    private func progressFill(fractionCompleted: Double) -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(fractionCompleted))
            .stroke(gradient, lineWidth: lineWidth)
            .frame(width: size)
            .rotationEffect(.degrees(-90))
    }
}
