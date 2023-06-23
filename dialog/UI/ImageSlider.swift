//
//  ImageSlider.swift
//  imagetest
//
//  Created by Bart Reardon on 3/12/21.
//

// Basis for this view was taken from the following stack overflow post https://stackoverflow.com/questions/58896661/swiftui-create-image-slider-with-dots-as-indicators

import SwiftUI

    
struct ImageSlider<Content>: View where Content: View {

    @Binding var index: Int
    let maxIndex: Int
    let content: () -> Content
    let autoPlaySeconds: Double
    let imageoffset: CGFloat

    @State private var offset = CGFloat.zero
    @State private var dragging = false

    init(index: Binding<Int>, maxIndex: Int, autoPlaySeconds: Double, @ViewBuilder content: @escaping () -> Content) {
        self._index = index
        self.maxIndex = maxIndex
        self.content = content
        self.autoPlaySeconds = autoPlaySeconds
        if maxIndex > 0 {
            imageoffset = 60
        } else {
            imageoffset = 0
        }
    }
    
    var body: some View {
        HStack {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            self.content()
                                .frame(width: geometry.size.width, height: geometry.size.height-imageoffset)
                                .clipped()
                        }
                    }
                    .content.offset(x: self.offset(in: geometry), y: 0)
                    .frame(width: geometry.size.width, alignment: .leading)
                }
                .clipped()
                if maxIndex > 0 {
                    PageControl(index: $index.animation(.easeInOut(duration: 0.5)), maxIndex: maxIndex, autoPlaySeconds: autoPlaySeconds)
                }
            }
        }
    }

    func offset(in geometry: GeometryProxy) -> CGFloat {
        if self.dragging {
            return max(min(self.offset, 0), -CGFloat(self.maxIndex) * geometry.size.width)
        } else {
            return -CGFloat(self.index) * geometry.size.width
        }
    }
}

struct PageControl: View {
    @Binding var index: Int
    let maxIndex: Int
    let autoPlaySeconds: Double
    
    @State private var timerTicks: Double = 0
    @State private var timerDisplay = 0.0
        
    func moveimage(direction: String) {
        switch direction {
        case "left":
            if index > 0 {
                index -= 1
            }
        case "right":
            if index < maxIndex {
                index += 1
            }
        default:
            // reset index to 0
            index = 0
        }
        timerTicks = 0
        timerDisplay = 0
    }
    
    func rotateIndex() {
        index += 1
        if index > maxIndex {
            index = 0
        }
    }
    
    // change image every 4 seconds (TODO: remove and make this a configurable paramater)
    var autoPlayTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var countDownTimer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    @State private var countDownTimerWidth: CGFloat = 0
    
    var body: some View {
        // display our own progress timer
        if autoPlaySeconds > 0 {
            GeometryReader { barWidth in
                VStack {
                    Spacer()
                    ZStack(alignment: .leading) {
                        Rectangle() // background of the progress bar
                            .fill(Color.secondary.opacity(0.5))
                            .frame(height: 8)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: countDownTimerWidth, height: 8, alignment: .bottomLeading)
                    }
                    .cornerRadius(10)
                    .frame(alignment: .bottom)
                    .onReceive(countDownTimer) { _ in
                        if timerDisplay < (autoPlaySeconds)*100 {
                            timerDisplay += 1
                            if timerDisplay == (autoPlaySeconds)*100 {
                                timerDisplay = 0
                            }
                            if timerDisplay > 30 {
                                countDownTimerWidth = (barWidth.size.width/((autoPlaySeconds*100)-10))*timerDisplay
                            } else {
                                countDownTimerWidth = 0
                            }
                        } else {
                            timerDisplay = 0
                        }
                    }
                }
            }
        }
        
        HStack(spacing: 8) {
            // move image left chevron
            
            Button(action: {moveimage(direction: "left")}, label: {
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
            
            // Centre dots
            ForEach(0...maxIndex, id: \.self) { index in
                Circle()
                    .fill(index == self.index ? Color.primary: Color.secondary)
                    .frame(width: 8, height: 8)
            }
            
            Spacer()
            
            // move image right chevron
            Button(action: {moveimage(direction: "right")}, label: {
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
        .opacity(0.80)
        .buttonStyle(.borderless)
        .padding(15)
        // increment the image index. reset to 0 when we reach the end
        .onReceive(autoPlayTimer) { _ in
            if autoPlaySeconds > 0 {
                timerTicks += 1
                if timerTicks == autoPlaySeconds {
                    rotateIndex()
                    timerTicks = 0
                }
            }
        }

    }
}
