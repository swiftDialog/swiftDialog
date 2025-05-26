//
//  MessageContentView.swift
//  Dialog
//
//  Created by Reardon, Bart  on 19/3/21.
//

import Foundation
import SwiftUI
import MarkdownUI

struct MessageContent: View {

    @ObservedObject var observedData: DialogUpdatableContent
    @State private var messageHeight: CGFloat

    var fieldPadding: CGFloat = 15
    var dataEntryMaxWidth: CGFloat = 700
    let defaultMessageHeight: CGFloat = 50

    var messageColour: Color

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
                                        .background(GeometryReader {child -> Color in
                                            DispatchQueue.main.async {
                                                // update on next cycle with calculated height
                                                self.messageHeight = child.size.height > defaultMessageHeight ? child.size.height : defaultMessageHeight
                                            }
                                            return Color.clear
                                        })
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(Color("editorBackgroundColour"))
                                .cornerRadius(5.0)
                                .border(observedData.appProperties.debugBorderColour, width: 2)
                            }
                        } else {
                            ScrollView {
                                ForEach(parseMarkdownSections(from: observedData.args.messageOption.value), id: \.id) { section in
                                    if section.isCollapsible {
                                        CollapsibleBlock(title: section.title ?? "Details", content: section.content)
                                        .markdownTextStyle {
                                            FontSize(appvars.messageFontSize-2)
                                            ForegroundColor(messageColour)
                                        }
                                        .padding(.vertical, 2)
                                        .focusable(false)
                                    } else {
                                        Markdown(section.content)
                                            .frame(width: messageGeometry.size.width, alignment: observedData.appProperties.messagePosition)
                                            .multilineTextAlignment(observedData.appProperties.messageAlignment)
                                            .lineSpacing(2)
                                            .fixedSize()
                                            /*
                                             // Leaving this commented out for now just in case we need it back
                                            .background(GeometryReader {child -> Color in
                                                DispatchQueue.main.async {
                                                    // update on next cycle with calculated height
                                                    self.messageHeight = child.size.height > defaultMessageHeight ? child.size.height : defaultMessageHeight
                                                }
                                                return Color.clear
                                            })
                                             */
                                            .markdownTheme(.sdMarkdown)
                                            .markdownTextStyle {
                                                FontSize(appvars.messageFontSize)
                                                ForegroundColor(messageColour)
                                            }
                                            .accessibilityHint(observedData.args.messageOption.value)
                                            .focusable(false)
                                            .border(observedData.appProperties.debugBorderColour, width: 2)
                                    }
                                }
                            }
                        }
                }
                // Will be interesting is commenting out this line causes issues
                //.frame(minHeight: 30, maxHeight: messageHeight)
                if !observedData.args.messageVerticalAlignment.present || ["centre", "center", "top"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }
            }

            Group {
                ForEach(Array(observedData.appProperties.viewOrder.indices), id: \.self) { index in
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.textfile.rawValue) == index {
                        TextFileView(logFilePath: observedData.args.logFileToTail.value)
                            .padding(.bottom, appDefaults.contentPadding)
                    }
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.webcontent.rawValue) == index {
                        WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.bottom, appDefaults.contentPadding)
                    }
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.listitem.rawValue) == index {
                        ListView(observedDialogContent: observedData)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.bottom, appDefaults.contentPadding)
                    }
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.checkbox.rawValue) == index {
                        CheckboxView(observedDialogContent: observedData)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth)
                    }
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.textfield.rawValue) == index {
                        TextEntryView(observedDialogContent: observedData, textfieldContent: userInputState.textFields)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth)
                    }
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.radiobutton.rawValue) == index {
                        RadioView(observedDialogContent: observedData)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth)
                    }
                    if observedData.appProperties.viewOrder.firstIndex(of: ViewType.dropdown.rawValue) == index {
                        DropdownView(observedDialogContent: observedData)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: .leading)
                    }
                }
            }


            if ["top"].contains(observedData.args.messageVerticalAlignment.value) {
                Spacer()
            }
            if observedData.appProperties.userInputRequired {
                HStack {
                    Spacer()
                    Text("required-note")
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
                Markdown(content)
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

func parseMarkdownSections(from text: String) -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
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
