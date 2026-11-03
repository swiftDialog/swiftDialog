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
    @State private var contentOpacity: Double = 0
    
    var messageMinHeight: CGFloat = 50
    var fieldPadding: CGFloat = 15
    var dataEntryMaxWidth: CGFloat = 700
    let defaultMessageHeight: CGFloat = 50

    var messageColour: Color
    var logHistoryLimit: Int

    var iconDisplayWidth: CGFloat

    let theAllignment: Alignment = .topLeading

    /// Navigation style lays content out top-down and left-aligned in a single scroll view,
    /// rather than pinning the message to the top and user input to the bottom.
    private var isNavigation: Bool { cardState.isNavigationStyle }

    /// Navigation style: height given to content that scrolls itself (list items, web, log, EULA),
    /// which would otherwise collapse inside the page's scroll view.
    let navigationScrollingContentHeight: CGFloat = 250

    /// Navigation style: height given to the main image / slideshow.
    let navigationImageHeight: CGFloat = 300

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
        if isNavigation {
            ScrollView(.vertical) {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            // New scroll position (top) for each page
            .id(observedData.currentCardIndex)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: isNavigation ? .leading : .center) {
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
                            // Iterate the collection's indices, not 0..<count: a Range-based ForEach
                            // pins to the count it first saw and keeps evaluating stale indices after
                            // the array shrinks on a card change, which traps on subscript.
                            ForEach(Array(userInputState.iconItems.indices), id: \.self) {index in
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
                    .id(observedData.currentCardIndex)
                    // Sized from a GeometryReader, which collapses inside the page's ScrollView
                    .frame(height: isNavigation ? navigationImageHeight : nil)
            }

            if !["", "none"].contains(observedData.args.messageOption.value) && isNavigation {
                // Navigation style: natural height, scrolls with the rest of the page
                if observedData.args.eulaMode.present {
                    eulaMessage
                        .frame(height: navigationScrollingContentHeight)
                } else {
                    styledMessage(
                        StructuredText(observedData.args.messageOption.value,
                                       parser: ColoredMarkdownParser())
                            .frame(maxWidth: .infinity, alignment: observedData.appProperties.messagePosition)
                            .multilineTextAlignment(observedData.appProperties.messageAlignment)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    )
                    .padding(.top, appDefaults.topPadding)
                }
            } else if !["", "none"].contains(observedData.args.messageOption.value) {
                if ["centre", "center", "bottom"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }

                GeometryReader { messageGeometry in
                        if observedData.args.eulaMode.present {
                            eulaMessage
                        } else {
                            ScrollView {
                                styledMessage(
                                    StructuredText(observedData.args.messageOption.value,
                                                   parser: ColoredMarkdownParser())
                                        .frame(width: messageGeometry.size.width, alignment: observedData.appProperties.messagePosition)
                                        .multilineTextAlignment(observedData.appProperties.messageAlignment)
                                        .lineSpacing(2)
                                        .fixedSize()
                                        .onGeometryChange(for: CGFloat.self) { proxy in
                                            max(proxy.size.height, defaultMessageHeight)
                                        } action: { newValue in
                                            messageHeight = newValue
                                        }
                                )
                            }
                            .padding(.top, appDefaults.topPadding)
                        }
                }
                .frame(minHeight: messageMinHeight, maxHeight: messageHeight+10)
                if !observedData.args.messageVerticalAlignment.present || ["centre", "center", "top"].contains(observedData.args.messageVerticalAlignment.value) {
                    Spacer()
                }
            } else if !isNavigation {
                Spacer()
            }
            
            // Show Audio Controls
            if observedData.args.showSoundControls.present && observedData.args.playSound.present {
                AudioControl()
            }

            if let layout = observedData.appProperties.viewLayout {
                // Extended vieworder: individual inputs placed in groups
                GroupedInputsView(observedData: observedData, groups: layout)
                    .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
            } else {
            Group {
                ForEach(Array(observedData.appProperties.viewOrder.indices), id: \.self) { index in
                    switch index {
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.textfile.rawValue):
                        TextFileView(logFilePath: observedData.args.logFileToTail.value, loadHistory: observedData.args.logFileHistory.present, historyLineLimit: logHistoryLimit)
                            .frame(height: isNavigation ? navigationScrollingContentHeight : nil)
                            .padding(.bottom, appDefaults.contentPadding)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.webcontent.rawValue):
                        WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                            .frame(height: isNavigation ? navigationScrollingContentHeight : nil)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.bottom, appDefaults.contentPadding)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.listitem.rawValue):
                        ListView(observedDialogContent: observedData)
                            .id(observedData.currentCardIndex)
                            .frame(height: isNavigation ? navigationScrollingContentHeight : nil)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .padding(.bottom, appDefaults.contentPadding)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.checkbox.rawValue):
                        CheckboxView(observedDialogContent: observedData)
                            .id(observedData.currentCardIndex)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.textfield.rawValue):
                        TextEntryView(observedDialogContent: observedData)
                            .id(observedData.currentCardIndex)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.dropdown.rawValue):
                        DropdownView(observedDialogContent: observedData)
                            .id(observedData.currentCardIndex)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: .leading)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.radiobutton.rawValue):
                        RadioView(observedDialogContent: observedData)
                            .id(observedData.currentCardIndex)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.button.rawValue):
                        ButtonRowView(observedDialogContent: observedData)
                            .id(observedData.currentCardIndex)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.slider.rawValue):
                        NumberInputView(observedDialogContent: observedData, kind: "slider")
                            .id(observedData.currentCardIndex)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
                    case observedData.appProperties.viewOrder.firstIndex(of: ViewType.stepper.rawValue):
                        NumberInputView(observedDialogContent: observedData, kind: "stepper")
                            .id(observedData.currentCardIndex)
                            .padding(.bottom, appDefaults.contentPadding)
                            .border(observedData.appProperties.debugBorderColour, width: 2)
                            .frame(maxWidth: dataEntryMaxWidth, alignment: isNavigation ? .leading : .center)
                    default:
                            EmptyView()
                    }
                }
            }
            }


            if !isNavigation && ["top"].contains(observedData.args.messageVerticalAlignment.value) {
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
        .opacity(contentOpacity)
        .onAppear {
            contentOpacity = 0
            withAnimation(.easeInOut(duration: 0.25)) {
                contentOpacity = 1
            }
        }
    }

    /// EULA mode: the message as monospaced text in a scrolling list.
    private var eulaMessage: some View {
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
    }

    /// Markdown styling, font and colour applied to the message, shared by the standard
    /// layout and the navigation style layout.
    private func styledMessage<Content: View>(_ message: Content) -> some View {
        message
            // Instead of .textual.structuredTextStyle(.gitHub), set each piece individually:
            .textual.inlineStyle(
                InlineStyle()
                    .code(.monospaced, .fontScale(0.85))  // same as .gitHub but NO .backgroundColor
                    .strong(.fontWeight(.semibold))
                    //.link(.foregroundColor(.gitHubLink))
            )
            .textual.headingStyle(.gitHub)
            .textual.paragraphStyle(.gitHub)
            .textual.blockQuoteStyle(.gitHub)
            .textual.codeBlockStyle(.gitHub)
            .textual.listItemStyle(.default)
            .textual.unorderedListMarker(.hierarchical(.disc, .circle, .square))
            .textual.orderedListMarker(.decimal)
            .textual.tableStyle(.gitHub)
            .textual.tableCellStyle(.gitHub)
            .textual.thematicBreakStyle(.gitHub)
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
}
