//
//  ListView.swift
//  dialog
//
//  Created by Bart Reardon on 27/1/2022.
//

import SwiftUI

extension NSTableView {
  open override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    backgroundColor = NSColor.clear
    enclosingScrollView!.drawsBackground = false
  }
}

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
    
    var rowHeight: CGFloat = appvars.messageFontSize + 14
    var rowStatusHeight: CGFloat = appvars.messageFontSize + 5
    var rowFontSize: CGFloat = appvars.messageFontSize
    var proportionalListHeight: CGFloat = 0
    
    init(observedDialogContent : DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
        if cloptions.listStyle.present {
            switch cloptions.listStyle.value {
            case "expanded":
                rowHeight = rowHeight + 15
            case "compact":
                rowHeight = rowHeight - 10
            //case "proportional":
            //    rowHeight = 0
            //    proportionalListHeight = 1
            default: ()
            }
        }
    }
    
    
    var body: some View {
        if observedDialogContent.listItemPresent {
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    let listHeightPadding = ((geometry.size.height/CGFloat(observedDialogContent.listItemsArray.count)/2) * proportionalListHeight)
                //withAnimation(.default) {
                    VStack() {
                        List(0..<observedDialogContent.listItemsArray.count, id: \.self) {i in
                            VStack {
                                HStack {
                                    if observedDialogContent.listItemsArray[i].icon != "" {
                                        IconView(observedDialogContent: observedDialogContent, image: observedDialogContent.listItemsArray[i].icon)
                                            .frame(maxHeight: rowHeight)
                                    }
                                    Text(observedDialogContent.listItemsArray[i].title)
                                        .font(.system(size: rowFontSize))
                                        .id(i)
                                    Spacer()
                                    HStack {
                                        if observedDialogContent.listItemsArray[i].statusText != "" {
                                            Text(observedDialogContent.listItemsArray[i].statusText)
                                                .font(.system(size: (rowFontSize * 0.8)))
                                                .foregroundColor(.secondary)
                                                .transition(AnyTransition.opacity.animation(.easeInOut(duration:0.2)))
                                        }
                                        switch observedDialogContent.listItemsArray[i].statusIcon {
                                        case "progress" :
                                            ProgressView("", value: observedDialogContent.listItemsArray[i].progress, total: 100)
                                                .progressViewStyle(CirclerPercentageProgressViewStyle())
                                                .frame(width: rowStatusHeight, height: rowStatusHeight-5)
                                                .transition(AnyTransition.opacity.animation(.easeInOut(duration:0.2)))
                                        case "wait" :
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .scaleEffect(0.8, anchor: .trailing)
                                                .frame(height: rowStatusHeight)
                                                .transition(AnyTransition.opacity.animation(.easeInOut(duration:0.2)))
                                        case "success" :
                                            StatusImage(name: "checkmark.circle.fill", colour: .green, size: rowStatusHeight)
                                        case "fail" :
                                            StatusImage(name: "xmark.circle.fill", colour: .red, size: rowStatusHeight)
                                        case "pending" :
                                            StatusImage(name: "ellipsis.circle.fill", colour: .gray, size: rowStatusHeight)
                                        case "error" :
                                            StatusImage(name: "exclamationmark.circle.fill", colour: .yellow, size: rowStatusHeight)
                                        default:
                                            EmptyView()
                                        }
                                    }
                                    //.animation(.easeInOut(duration: 5))
                                    //.transition(.opacity)
                                }
                                .frame(height: rowHeight+listHeightPadding)
                                Divider()
                            }
                            //.frame(height: rowHeight+listHeightPadding)
                        }
                        .background(Color("editorBackgroundColour"))
                    }
                    .onChange(of: observedDialogContent.listItemUpdateRow, perform: { _ in
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(observedDialogContent.listItemUpdateRow)
                            }
                        }
                    })
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct CirclerPercentageProgressViewStyle : ProgressViewStyle {
    public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
        let stroke : CGFloat = 5
        let padding : CGFloat = stroke / 2
        VStack() {
            ZStack {
                Circle()
                    .stroke(lineWidth: stroke)
                    .opacity(0.3)
                    .foregroundColor(Color.accentColor.opacity(0.5))
                Circle()
                    .trim(from: 0.0, to: CGFloat(configuration.fractionCompleted ?? 0))
                .stroke(style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.accentColor)
                .rotationEffect(.degrees(-90))
                //.animation(.linear)
            }
            .animation(.linear)
            .padding(.trailing, padding)
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
