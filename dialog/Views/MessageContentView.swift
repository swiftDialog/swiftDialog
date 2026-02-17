//
//  MessageContentView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI
import Textual

struct MessageContent: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State private var messageHeight: CGFloat
    
    var messageMinHeight: CGFloat = 50
    var fieldPadding: CGFloat = 15
    var dataEntryMaxWidth: CGFloat = 700
    let defaultMessageHeight: CGFloat = 50

    var messageColour: Color
    var logHistoryLimit: Int

    var iconDisplayWidth: CGFloat

    let theAllignment: Alignment = .topLeading

    init(observedDialogContent: DialogUpdatableContent) {
        writeLog("Displaying main message content")
        self.observedData = observedDialogContent
        self.messageHeight = defaultMessageHeight
        if !observedDialogContent.args.iconOption.present { //cloptions.hideIcon.present {
            writeLog("Icon is hidden")
            fieldPadding = 30
            iconDisplayWidth = 0
        } else {
            fieldPadding = 20
            iconDisplayWidth = observedDialogContent.iconSize
        }
        messageColour = observedDialogContent.appProperties.messageFontColour
        self.logHistoryLimit = Int(observedDialogContent.args.logFileHistory.value) ?? appvars.logFileHistory
    }

    var body: some View {
        VStack {
            if observedData.args.centreIcon.present && observedData.args.iconOption.present {
                HStack {
                    Spacer()
                    HStack {
                        if userInputState.iconItems.count == 1 {
                            IconView(image: observedData.args.iconOption.value,
                                     overlay: observedData.args.overlayIconOption.value,
                                     alpha: observedData.iconAlpha)
                            .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                            .frame(width: iconDisplayWidth, alignment: .top)
                        } else {
                            ForEach(0..<userInputState.iconItems.count, id: \.self) {index in
                                IconView(image: userInputState.iconItems[index].value,
                                         alpha: observedData.iconAlpha)
                                .frame(height: iconDisplayWidth, alignment: .top)
                                
                            }
                        }
                    }
                    .border(observedData.appProperties.debugBorderColour, width: 2)
                    .accessibilityHint(observedData.args.iconAccessabilityLabel.value)
                    Spacer()
                }
                .frame(maxWidth: appvars.windowWidth*0.8)
                .frame(maxHeight: iconDisplayWidth)
            }

            if observedData.args.mainImage.present {
                ImageView(imageArray: observedData.imageArray, captionArray: observedData.appProperties.imageCaptionArray, autoPlaySeconds: observedData.args.autoPlay.value.floatValue(), showControls: true, hideTimer: observedData.args.hideTimer.present)
            }

            if !["", "none"].contains(observedData.args.messageOption.value) {
                if ["centre", "center", "bottom"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }

                GeometryReader { messageGeometry in
                        if observedData.args.eulaMode.present {
                            HStack {
                                List {
                                    Text(observedData.args.messageOption.value)
                                        .font(.system(size: 12, design: .monospaced))
                                        .background(GeometryReader { child in
                                            Color.clear
                                                .onAppear {
                                                    self.messageHeight = child.size.height > defaultMessageHeight ? child.size.height : defaultMessageHeight
                                                }
                                        })
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(Color("editorBackgroundColour"))
                                .cornerRadius(5.0)
                                .border(observedData.appProperties.debugBorderColour, width: 2)
                            }
                        } else {
                            ScrollView {
                                
                                StructuredText(observedData.args.messageOption.value,
                                               parser: ColoredMarkdownParser())
                                    .frame(width: messageGeometry.size.width, alignment: observedData.appProperties.messagePosition)
                                    .multilineTextAlignment(observedData.appProperties.messageAlignment)
                                    .lineSpacing(2)
                                    .fixedSize()
                                    .background(GeometryReader {child -> Color in
                                        DispatchQueue.main.async {
                                            // update on next cycle with calculated height
                                            self.messageHeight = child.size.height > defaultMessageHeight ? child.size.height : defaultMessageHeight
                                        }
                                        return Color.clear
                                    })
                                    .textual.structuredTextStyle(.gitHub)
                                    .textual.textSelection(.enabled)
                                    .font(
                                        appvars.messageFontName.isEmpty ?
                                        Font.system(size: appvars.messageFontSize, weight: appvars.messageFontWeight, design: .default) :
                                        .custom(appvars.messageFontName, size: appvars.messageFontSize)
                                    )
                                    .fontWeight(appvars.messageFontWeight)
                                    .foregroundColor(messageColour)
                                    .accessibilityHint(observedData.args.messageOption.value)
                                    .focusable(false)
                                    .border(observedData.appProperties.debugBorderColour, width: 2)
                            }
                            .padding(.top, appDefaults.topPadding)
                        }
                }
                .frame(minHeight: messageMinHeight, maxHeight: messageHeight+10)
                if !observedData.args.messageVerticalAlignment.present || ["centre", "center", "top"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }
            } else {
                Spacer()
            }
            
            // Show Audio Controls
            if observedData.args.showSoundControls.present && observedData.args.playSound.present {
                AudioControl()
            }

            Group {
                ForEach(Array(observedData.appProperties.viewOrder.indices), id: \.self) { index in
                    switch index {
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.textfile.rawValue):
                        TextFileView(logFilePath: observedData.args.logFileToTail.value, loadHistory: observedData.args.logFileHistory.present, historyLineLimit: logHistoryLimit)
                            .padding(.bottom, appDefaults.contentPadding)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.webcontent.rawValue):
                        WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.bottom, appDefaults.contentPadding)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.listitem.rawValue):
                        ListView(observedDialogContent: observedData)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.bottom, appDefaults.contentPadding)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.checkbox.rawValue):
                        CheckboxView(observedDialogContent: observedData)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.textfield.rawValue):
                        TextEntryView(observedDialogContent: observedData, textfieldContent: userInputState.textFields)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.dropdown.rawValue):
                        DropdownView(observedDialogContent: observedData)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: .leading)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.radiobutton.rawValue):
                        RadioView(observedDialogContent: observedData)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth)
                    default:
                            EmptyView()
                    }
                }
            }


            if ["top"].contains(observedData.args.messageVerticalAlignment.value) {
                Spacer()
            }
            if observedData.appProperties.userInputRequired {
                HStack {
                    Spacer()
                    Text("* Required Fields")
                        .font(.system(size: 10)
                                .weight(.light))
                }
            }
        }
        .padding(.leading, appDefaults.sidePadding)
        .padding(.trailing, appDefaults.sidePadding)
        .padding(.top, appDefaults.topPadding)
        .textSelection(.enabled)
    }
}

struct PriorityView<Content: View>: View {
    private var content: () -> Content
    private var priority: Int

    init(priority: Int, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.priority = priority
    }

    var body: some View {
        EmptyView()
            .overlay(content())
            .zIndex(Double(priority))
    }
}

struct MarkdownSection: Identifiable {
    let id = UUID()
    let isCollapsible: Bool
    let title: String?
    let content: String
}

struct CollapsibleBlock: View {
    let title: String
    let content: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                StructuredText(markdown: content)
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

func parseMarkdownSections(from text: String) -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var index = 0

        while index < lines.count {
                let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.starts(with: "::~") {
                let title = line.replacingOccurrences(of: "::~", with: "").trimmingCharacters(in: .whitespaces)
                var content = ""
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).starts(with: ":::") {
                    content += lines[index] + "\n"
                    index += 1
                }
                // Skip the ::: end line
                index += 1
                sections.append(.init(isCollapsible: true, title: title, content: content))
            } else {
                var content = ""
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).starts(with: "::~") {
                    content += lines[index] + "\n"
                    index += 1
                }
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sections.append(.init(isCollapsible: false, title: nil, content: content))
                }
            }
        }

        return sections
    }
