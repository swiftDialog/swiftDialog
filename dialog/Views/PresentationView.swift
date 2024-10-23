//
//  PresentationView.swift
//  Dialog
//
//  Created by Bart E Reardon on 5/3/2024.
//

import SwiftUI
import MarkdownUI

struct PresentationView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    var messageColour: Color
    var infoColour: Color
    var backgroundColour: Color
    //Color(.accentColor).isDark ? Color.white : Color.black
    var imageList: Array = [String]()
    var autoPlaySeconds: CGFloat

    let sbWidthProportion = 0.3

    init(observedData: DialogUpdatableContent) {
        self.observedData = observedData
        self.backgroundColour = Color(argument: observedData.args.watermarkImage.value.components(separatedBy: "=").last ?? "accent")
        self.infoColour = self.backgroundColour.isDark ? Color.white : Color.black
        self.messageColour = observedData.appProperties.messageFontColour

        for index in 0..<observedData.imageArray.count where observedData.imageArray[index].path != "" {
            imageList.append(observedData.imageArray[index].path)
        }
        self.autoPlaySeconds = observedData.args.autoPlay.value.floatValue()
    }

    var body: some View {
        GeometryReader { content in
            Color.clear.onAppear {
                if !observedData.args.windowResizable.present {
                    observedData.appProperties.windowWidth = content.size.width
                }
            }
            VStack {
                // title
                //TitleView(observedData: observedData)
                // content
                GeometryReader { sidebar in
                    Color.clear.onAppear {
                        let sbImageWidth = (sidebar.size.width*sbWidthProportion).rounded()*2
                        let sbImageHeight = sidebar.size.height.rounded()*2
                        writeLog("Ideal presentation sidebar image size for these window dimensions would be width:\(sbImageWidth), height:\(sbImageHeight)", logLevel: .debug)
                    }
                    HStack {
                        if observedData.args.mainImage.present {
                            ImageFader(imageList: imageList, captionsList: [], autoPlaySeconds: autoPlaySeconds, showControls: false, showCorners: false, contentMode: .fill, hideTimer: true)
                            //.aspectRatio(contentMode: .fill)
                                .frame(maxWidth: content.size.width*sbWidthProportion)
                                .clipped()
                        } else if observedData.args.webcontent.present {
                            WebContentView(observedDialogContent: observedData, url: observedData.args.webcontent.value)
                                .frame(maxWidth: content.size.width*sbWidthProportion)
                        } else {
                            ZStack {
                                SolidColourView(colourValue: observedData.args.watermarkImage.present ? observedData.args.watermarkImage.value : "accent")

                                VStack {
                                    if observedData.args.iconOption.present && observedData.args.iconOption.value != "default" {
                                        HStack {
                                            IconView(image: observedData.args.iconOption.value, overlay: "", alpha: 1, padding: 10, sfPaddingEnabled: true)
                                                .frame(width: observedData.args.iconSize.value.floatValue())
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                PresentationViewMarkdown(content: observedData.args.infoBox.value,
                                                         contentAlignment: .leading,
                                                         contentColour: infoColour)
                            }
                            .frame(maxWidth: content.size.width*sbWidthProportion)
                        }

                        if observedData.args.listItem.present {
                            // list view
                            ListView(observedDialogContent: observedData, clipRadius: 0)
                        } else {
                            PresentationViewMarkdown(content: observedData.args.messageOption.value,
                                                     contentAlignment: .leading,
                                                     contentColour: messageColour)
                            .scrollOnOverflow()
                        }
                    }
                }

                // footer
                VStack {
                    ProgressView(value: observedData.progressValue, total: observedData.progressTotal)
                        .progressViewStyle(TaskProgressViewStyle())
                        .padding(.horizontal, 10)
                    Text(observedData.args.progressText.value)
                        .lineLimit(1)
                    // Buttons
                    ButtonView(observedDialogContent: observedData)
                        .padding(.leading, appDefaults.sidePadding)
                        .padding(.trailing, appDefaults.sidePadding)
                        .padding(.bottom, appDefaults.bottomPadding)
                        .border(observedData.appProperties.debugBorderColour, width: 2)
                }
            }
            .edgesIgnoringSafeArea(.top)
        }
    }
}

struct PresentationViewMarkdown: View {
    var content: String
    var contentAlignment: TextAlignment
    var contentColour: Color
    var body: some View {
        Markdown(content, baseURL: URL(string: "http://"))
            .multilineTextAlignment(contentAlignment)
            .markdownTheme(.sdMarkdown)
            .markdownTextStyle {
                FontSize(appvars.messageFontSize)
            }
            .focusable(false)
            .markdownTextStyle {
                FontSize(appvars.messageFontSize)
                ForegroundColor(contentColour)
            }
            .truncationMode(.tail)
            .padding(.all, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
