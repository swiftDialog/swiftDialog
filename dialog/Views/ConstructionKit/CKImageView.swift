//
//  CKImageView.swift
//  dialog
//
//  Created by Bart Reardon on 29/7/2022.
//

import SwiftUI

struct CKImageView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    observedData.imageArray.append(MainImage(path: ""))
                    observedData.args.mainImage.present = true
                }, label: {
                    Image(systemName: "plus")
                })
                Toggle("Show".localized, isOn: $observedData.args.mainImage.present)
                    .toggleStyle(.switch)
                Toggle("AutoPlay".localized, isOn: $observedData.args.autoPlay.present)
                    .toggleStyle(.switch)
                TextField("Autoplay Seconds".localized, text: $observedData.args.autoPlay.value)
                Spacer()
            }
            
            //ForEach(observedData.listItemsArray, id: \.self)
            List {
                ForEach(0..<observedData.imageArray.count, id: \.self) { item in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                        
                        IconView(image: observedData.imageArray[item].path)
                            .frame(width: 48, height: 48)
                            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                                guard let provider = providers.first else { return false }
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    if let url = url {
                                        DispatchQueue.main.async {
                                            observedData.imageArray[item].path = url.path
                                        }
                                    }
                                }
                                return true
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                        Button("Select".localized) {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseDirectories = false
                            panel.allowedContentTypes = [.image]
                            if panel.runModal() == .OK {
                                observedData.imageArray[item].path = panel.url?.path ?? "<none>"
                            }
                        }
                        TextField("Path".localized, text: $observedData.imageArray[item].path)
                        TextField("Caption".localized, text: $observedData.imageArray[item].caption)
                        Button(action: {
                            guard item >= 0 && item < observedData.imageArray.count else {
                                writeLog("Could not delete item at position \(item)", logLevel: .info)
                                return
                            }
                            writeLog("Delete item at position \(item)", logLevel: .info)
                            observedData.imageArray.remove(at: item)
                        }, label: {
                            Image(systemName: "trash")
                        })
                    }
                }
                .onMove { from, to in
                    withAnimation(.smooth) {
                        observedData.imageArray.move(fromOffsets: from, toOffset: to)
                    }
                }
            }
            HStack {
                Text("Drop New Image(s) Here")
                    .font(.title3.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundColor(.gray.opacity(0.5))
                    )
                    
            }
            .padding(.top, 20)
                
            Spacer()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            observedData.imageArray.append(MainImage(path: url.path))
                            observedData.args.mainImage.present = true
                        }
                    }
                }
            }
            return true
        }
        .padding(20)
    }
}
