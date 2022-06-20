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
    var statusSize: CGFloat
    
    init(name: String, colour: Color, size: CGFloat) {
        self.name = name
        self.colour = colour
        self.statusSize = size
    }
    
    var body: some View {
        Image(systemName: name)
            .resizable()
            .foregroundColor(colour)
            .scaledToFit()
            .frame(width: statusSize, height: statusSize)
            //.border(.red)
            .transition(AnyTransition.opacity.animation(.easeInOut(duration:0.2)))
    }
}

struct ListView: View {
    
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    var listHeight: CGFloat = appvars.messageFontSize + 14
    var statusHeight: CGFloat = appvars.messageFontSize + 5
    var fontSize: CGFloat = appvars.messageFontSize
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if cloptions.listStyle.present {
            switch cloptions.listStyle.value {
            case "expanded":
                listHeight = listHeight + 15
                //statusHeight = statusHeight + 10
                //fontSize = 30
            case "compact":
                listHeight = listHeight - 15
                //statusHeight = statusHeight - 10
                //fontSize = 15
            default: ()
            }
        }
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
                                        .font(.system(size: fontSize))
                                        .id(i)
                                    Spacer()
                                    HStack {
                                        if observedDialogContent.listItemsArray[i].statusText != "" {
                                            Text(observedDialogContent.listItemsArray[i].statusText)
                                                .font(.system(size: fontSize))
                                                .transition(AnyTransition.opacity.animation(.easeInOut(duration:0.2)))
                                        }
                                        switch observedDialogContent.listItemsArray[i].statusIcon {
                                        case "wait" :
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .scaleEffect(0.8, anchor: .trailing)
                                                .frame(height: statusHeight)
                                                .transition(AnyTransition.opacity.animation(.easeInOut(duration:0.2)))
                                        case "success" :
                                            StatusImage(name: "checkmark.circle.fill", colour: .green, size: statusHeight)
                                        case "fail" :
                                            StatusImage(name: "xmark.circle.fill", colour: .red, size: statusHeight)
                                        case "pending" :
                                            StatusImage(name: "ellipsis.circle.fill", colour: .gray, size: statusHeight)
                                        case "error" :
                                            StatusImage(name: "exclamationmark.circle.fill", colour: .yellow, size: statusHeight)
                                        default:
                                            EmptyView()
                                        }
                                    }
                                    //.animation(.easeInOut(duration: 5))
                                    //.transition(.opacity)
                                }
                                .frame(height: listHeight)
                                Divider()
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
