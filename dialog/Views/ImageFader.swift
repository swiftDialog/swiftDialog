//
//  ImageFader.swift
//  Dialog
//
//  Created by Bart E Reardon on 9/3/2024.
//

import SwiftUI

struct ImageFader: View {
    @State var visibleIndex: Int = 0
    @State private var timerTicks: Double = 0

    var imageList: [String]
    var captionsList: [String]
    var autoPlaySeconds: CGFloat = 0
    var showControls: Bool = false
    var showCorners: Bool = false
    var contentMode: ContentMode = .fit

    var autoPlayTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func incrementIndex() {
        visibleIndex+=1
        if visibleIndex == imageList.count {
            visibleIndex = 0
        }
    }

    func decrementIndex() {
        visibleIndex-=1
        if visibleIndex < 0 {
            visibleIndex = imageList.count
        }
    }

    func incrementTimer() {
        timerTicks += 1
        if timerTicks == autoPlaySeconds {
            timerTicks = 0
            incrementIndex()
        }
    }

    var body: some View {
        HStack {
            Spacer()
            ZStack {
                ForEach(0..<imageList.count, id: \.self) { index in
                    VStack {
                        DisplayImage(imageList[index], corners: showCorners, content: contentMode)
                        if captionsList.count > 0 {
                            if appArguments.fullScreenWindow.present {
                                Text(captionsList[index])
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                            } else {
                                Text(captionsList[index])
                                    .font(.system(size: 20))
                                    .italic()
                            }
                        }
                    }
                    .opacity(index==visibleIndex ? 1 : 0)
                    //.frame(maxHeight: .infinity)
                }
                if imageList.count > 1 && showControls && autoPlaySeconds < 1 {
                    FaderControls(increment: incrementIndex, decrement: decrementIndex)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: visibleIndex)
            .onReceive(autoPlayTimer) { _ in
                if autoPlaySeconds > 0 {
                    incrementTimer()
                }
            }
            Spacer()
        }
    }
}

struct FaderControls: View {

    var increment: () -> Void
    var decrement: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: {decrement()}, label: {
                    ZStack {
                        Image(systemName: "circle.fill")
                            .resizable()
                            .foregroundColor(Color.tertiaryBackground)

                        Image(systemName: "chevron.left.circle.fill")
                            .resizable()
                            .foregroundColor(Color.primary)
                    }
                })
                .frame(width: 20, height: 20)

                Spacer()

                // move image right chevron
                Button(action: {increment()}, label: {
                    ZStack {
                        Image(systemName: "circle.fill")
                            .resizable()
                            .foregroundColor(Color.tertiaryBackground)

                        Image(systemName: "chevron.right.circle.fill")
                            .resizable()
                            .foregroundColor(Color.primary)
                    }

                })
                .frame(width: 20, height: 20)
            }
            .opacity(0.70)
            .buttonStyle(.borderless)
            .padding(15)
        }
    }
}

