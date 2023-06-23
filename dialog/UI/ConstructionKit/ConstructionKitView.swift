//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI
import SwiftyJSON

var jsonFormattedOutout: String = ""

struct LabelView: View {
    var label: String
    var body: some View {
        VStack {
            Divider()
            HStack {
                Text(label)
                    .fontWeight(.bold)
                Spacer()
            }
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack {
            Image(systemName: "bubble.left.circle.fill")
                .resizable()
                .frame(width: 150, height: 150)

            Text("ck-welcome")
                .font(.largeTitle)
            Divider()
            Text("ck-welcomeinfo")
                .foregroundColor(.secondary)
        }
    }
}

struct JSONView: View {
    @ObservedObject var observedDialogContent: DialogUpdatableContent

    @State private var jsonText: String = ""

    private func exportJSON(debug: Bool = false) -> String {
        var json = JSON()
        var jsonDEBUG = JSON()

        // copy modifyable objects into args
        observedDialogContent.args.iconSize.value = "\(observedDialogContent.iconSize)"
        observedDialogContent.args.windowWidth.value = "\(observedDialogContent.windowWidth)"
        observedDialogContent.args.windowHeight.value = "\(observedDialogContent.windowHeight)"
        
        let mirroredAppArguments = Mirror(reflecting: observedDialogContent.args)
        for (_, attr) in mirroredAppArguments.children.enumerated() {
            if let propertyValue = attr.value as? CommandlineArgument {
                if propertyValue.present { //}&& propertyValue.value != "" {
                    if propertyValue.value != "" {
                        json[propertyValue.long].string = propertyValue.value
                    } else if propertyValue.isbool {
                        json[propertyValue.long].string = "\(propertyValue.present)"
                    }
                }
                jsonDEBUG[propertyValue.long].string = propertyValue.value
                jsonDEBUG["\(propertyValue.long)-present"].bool = propertyValue.present
            }
        }

        if observedDialogContent.listItemsArray.count > 0 {
            json[appArguments.listItem.long].arrayObject = Array(repeating: 0, count: observedDialogContent.listItemsArray.count)
            for index in 0..<observedDialogContent.listItemsArray.count {
                if observedDialogContent.listItemsArray[index].title.isEmpty {
                    observedDialogContent.listItemsArray[index].title = "Item \(index)"
                }
                // print(observedDialogContent.listItemsArray[i].dictionary)
                json[appArguments.listItem.long][index].dictionaryObject = observedDialogContent.listItemsArray[index].dictionary
            }
        }

        if observedDialogContent.imageArray.count > 0 {
            json[appArguments.mainImage.long].arrayObject = Array(repeating: 0, count: observedDialogContent.imageArray.count)
            for index in 0..<observedDialogContent.imageArray.count {
                json[appArguments.mainImage.long][index].dictionaryObject = observedDialogContent.imageArray[index].dictionary
            }
        }
        
        // message font stuff
        if observedDialogContent.appProperties.messageFontColour != .primary {
            json[appArguments.messageFont.long].dictionaryObject = ["colour": colourToString(color: observedDialogContent.appProperties.messageFontColour)]
        }
        
        if observedDialogContent.appProperties.titleFontColour != .primary {
            json[appArguments.titleFont.long].dictionaryObject = ["colour": colourToString(color: observedDialogContent.appProperties.titleFontColour)]
        }

        // convert the JSON to a raw String
        jsonFormattedOutout = json.rawString() ?? "json is nil"

        if debug {
            jsonFormattedOutout = jsonDEBUG.rawString() ?? ""
        }
        return jsonFormattedOutout
    }

    init (observedDialogContent: DialogUpdatableContent) {
        self.observedDialogContent = observedDialogContent
    }

    var body: some View {
        VStack {
            HStack {
                Button("Generate") {
                    jsonText = exportJSON()
                }
                Button("Copy to clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([NSString(string: exportJSON())])
                }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 10)
            Divider()
            HStack {
                Text(jsonText)
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 10)
            Spacer()
        }
    }
}

struct ConstructionKitView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent

        // mark all standard fields visible
        observedDialogContent.args.titleOption.present = true
        observedDialogContent.args.titleFont.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.messageOption.present = true
        observedDialogContent.args.iconOption.present = true
        observedDialogContent.args.iconSize.present = true
        observedDialogContent.args.button1TextOption.present = true
        observedDialogContent.args.windowWidth.present = true
        observedDialogContent.args.windowHeight.present = true

    }

    public func showConstructionKit() {

        var window: NSWindow!
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
               styleMask: [.titled, .closable, .miniaturizable, .resizable],
               backing: .buffered, defer: false)
        window.title = "swiftDialog Construction Kit (ALPHA)"
        window.makeKeyAndOrderFront(self)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ConstructionKitView(observedDialogContent: observedData))

    }

    var body: some View {

        NavigationView {
            List {
                Section(header: Text("ck-basic".localized)) {
                    NavigationLink(destination: CKBasicsView(observedDialogContent: observedData)) {
                        Text("ck-content".localized)
                    }
                    NavigationLink(destination: CKWindowProperties(observedDialogContent: observedData)) {
                        Text("ck-window".localized)
                    }
                    NavigationLink(destination: CKSidebarView(observedDialogContent: observedData)) {
                        Text("ck-sidebar".localized)
                    }
                    NavigationLink(destination: CKDataEntryView(observedDialogContent: observedData)) {
                        Text("ck-dataentry".localized)
                    }
                    NavigationLink(destination: CKButtonView(observedDialogContent: observedData)) {
                        Text("ck-buttons".localized)
                    }
                }
                Section(header: Text("ck-advanced".localized)) {
                    NavigationLink(destination: CKListView(observedDialogContent: observedData)) {
                        Text("ck-listitems".localized)
                    }
                    NavigationLink(destination: CKImageView(observedDialogContent: observedData)) {
                        Text("ck-images".localized)
                    }
                    NavigationLink(destination: CKMediaView(observedDialogContent: observedData)) {
                        Text("ck-media".localized)
                    }
                }
                Spacer()
                Section(header: Text("ck-output".localized)) {
                    NavigationLink(destination: JSONView(observedDialogContent: observedData) ) {
                        Text("ck-jsonoutput".localized)
                    }
                }
            }
            .padding(10)

            WelcomeView()
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 800, minHeight: 800)
        Divider()
        ZStack {
            Spacer()
            HStack {
                Button("ck-quit".localized) {
                    quitDialog(exitCode: observedData.appProperties.exit0.code)
                }
                Spacer()
                .disabled(false)
                Button("ck-exportcommand".localized) {}
                    .disabled(true)
            }
        }
        .padding(20)
    }
}
