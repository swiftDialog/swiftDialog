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
            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
            .contentTransition(.symbolEffect(.replace))
    }
}

struct ListView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    @State var isHovering = false
    //@State private var selection = Set<String>()
    @State private var selection = Set<Int>()
    
    var rowHeight: CGFloat
    var rowStatusHeight: CGFloat
    var rowFontSize: CGFloat
    var proportionalListHeight: CGFloat
    var subtitlePresent: Bool = false
    var clipRadius: CGFloat = 8

    init(observedDialogContent: DialogUpdatableContent, clipRadius: CGFloat = 8) {
        self.observedData = observedDialogContent
        self.clipRadius = clipRadius

        rowHeight = observedDialogContent.appProperties.messageFontSize + 14
        rowStatusHeight = observedDialogContent.appProperties.messageFontSize + 5
        rowFontSize = observedDialogContent.appProperties.messageFontSize
        proportionalListHeight = 0

        if appArguments.listStyle.present {
            switch appArguments.listStyle.value {
            case "expanded":
                rowHeight += 15
            case "compact":
                rowHeight -= 10
            //case "proportional":
            //    rowHeight = 0
            //    proportionalListHeight = 1
            default: ()
            }
        }
        for item in userInputState.listItems where !item.subTitle.isEmpty {
            rowHeight += 28
            subtitlePresent = true
            break
        }
    }

    func handleClick(_ item: String) {
        if !item.isEmpty {
            writeLog("User clicked list link \(item)", logLevel: .info)
            openSpecifiedURL(urlToOpen: item)
        }
    }


    var body: some View {
        if observedData.args.listItem.present {
            let _ = writeLog("Displaying listitems")
            ScrollViewReader { proxy in
                VStack {
                    List(0..<userInputState.listItems.count, id: \.self, selection: $selection) {index in
                        Button(action: {
                            if observedData.args.listSelectionEnabled.present {
                                if selection.contains(index) {
                                    selection.remove(index)
                                    userInputState.listItems[index].selected = false
                                } else {
                                    selection.insert(index)
                                    userInputState.listItems[index].selected = true
                                }
                            } else {
                                selection.remove(index)
                                handleClick(userInputState.listItems[index].action)
                            }
                        }) {
                            VStack {
                                HStack {
                                    if !userInputState.listItems[index].icon.isEmpty {
                                        let _ = writeLog("Switch index \(index): Displaying icon \(userInputState.listItems[index].icon)")
                                        IconView(image: userInputState.listItems[index].icon, overlay: "", alpha: userInputState.listItems[index].iconAlpha, sfPaddingEnabled: false, corners: false)
                                            .frame(maxHeight: rowHeight)
                                            .frame(width: rowHeight)
                                    }
                                    VStack {
                                        HStack {
                                            Text(userInputState.listItems[index].title)
                                                .font(.system(size: rowFontSize))
                                                .id(index)
                                            Spacer()
                                        }
                                        if subtitlePresent {
                                            HStack {
                                                Text(userInputState.listItems[index].subTitle)
                                                    .lineLimit(2)
                                                    .font(.system(size: rowFontSize-4))
                                                    .foregroundStyle(.secondary)
                                                //.padding(.top, 1)
                                                Spacer()
                                            }
                                        }
                                    }
                                    Spacer()
                                    HStack {
                                        if userInputState.listItems[index].statusText != "" {
                                            Text(userInputState.listItems[index].statusText)
                                                .font(.system(size: rowFontSize))
                                                .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
                                        }
                                        StatusView(status: userInputState.listItems[index].statusIcon, size: rowStatusHeight, progress: userInputState.listItems[index].progress)
                                    }
                                }
                                .frame(maxHeight: rowHeight)
                                Divider()
                            }
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering && !userInputState.listItems[index].action.isEmpty {
                                    isHovering = hovering
                                    NSCursor.pointingHand.push()
                                } else {
                                    isHovering = false
                                    NSCursor.pop()
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        //.listRowBackground(
                        //    selection.contains(index) ? Color.accentColor.opacity(0.3) : Color.clear
                        //)
                    }
                    .background(Color("listBackgroundColour"))
                    .listStyle(.sidebar)
                    //.listStyle(.plain)
                    
                }
                .onChange(of: observedData.listItemUpdateRow) {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(observedData.listItemUpdateRow, anchor: .center)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: clipRadius))
            }
        }
    }
}

struct StatusView: View {
    
    var status: String
    var size: CGFloat
    var progress: CGFloat = 0
    
    var body: some View {
        Group {
            switch status {
            case "progress":
                ProgressView("", value: progress, total: 100)
                    .progressViewStyle(CircularPercentageProgressViewStyle())
                    .frame(width: size, height: size-5)
            case "wait":
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8, anchor: .trailing)
                    .frame(height: size)
            case "success":
                StatusImage(name: "checkmark.circle.fill", colour: .green, size: size)
            case "fail":
                StatusImage(name: "xmark.circle.fill", colour: .red, size: size)
            case "pending":
                StatusImage(name: "ellipsis.circle.fill", colour: .gray, size: size)
            case "error":
                StatusImage(name: "exclamationmark.circle.fill", colour: .yellow, size: size)
            case "":
                EmptyView()
            default:
                let statusParts = status.split(separator: "-")
                let name = statusParts.first?.lowercased() ?? ""
                let colour = statusParts.count > 1 ? Color(argument: statusParts[1].lowercased()) : .primary
                StatusImage(name: name, colour: colour, size: size)
            }
        }
    }
}

struct CircularPercentageProgressViewStyle: ProgressViewStyle {
    public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
        let stroke: CGFloat = 5
        let padding: CGFloat = stroke / 2
        VStack {
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
            }
            .animation(.linear, value: configuration.fractionCompleted)
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
