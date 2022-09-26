//
//  ConstructionKitView.swift
//  dialog
//
//  Created by Bart Reardon on 29/6/2022.
//

import SwiftUI
import SwiftyJSON

var jsonFormattedOutout : String = ""

struct LabelView: View {
    var label : String
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
            
            Text("Welcome to the swiftDialog builder")
                .font(.largeTitle)
            Divider()
            Text("Select properties on the left to modify. swiftDialog will update to show the changes in realtime")
                .foregroundColor(.secondary)
        }
    }
}

struct JSONView: View {
    @ObservedObject var observedDialogContent : DialogUpdatableContent
    
    @State private var jsonText : String = ""
    
    private func exportJSON(debug : Bool = false) -> String {
        var json = JSON()
        var jsonDEBUG = JSON()
        
        // copy modifyable objects into args
        observedDialogContent.args.iconSize.value = "\(observedDialogContent.iconSize)"
        observedDialogContent.args.windowWidth.value = "\(observedDialogContent.windowWidth)"
        observedDialogContent.args.windowHeight.value = "\(observedDialogContent.windowHeight)"
        
        let mirrored_appArguments = Mirror(reflecting: observedDialogContent.args)
        for (_, attr) in mirrored_appArguments.children.enumerated() {
            if let propertyValue = attr.value as? CLArgument {
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
            for i in 0..<observedDialogContent.listItemsArray.count {
                if observedDialogContent.listItemsArray[i].title.isEmpty {
                    observedDialogContent.listItemsArray[i].title = "Item \(i)"
                }
                print(observedDialogContent.listItemsArray[i].dictionary)
                json[appArguments.listItem.long][i].dictionaryObject = observedDialogContent.listItemsArray[i].dictionary
            }
        }
        
        if observedDialogContent.imageArray.count > 0 {
            json[appArguments.mainImage.long].arrayObject = Array(repeating: 0, count: observedDialogContent.imageArray.count)
            for i in 0..<observedDialogContent.imageArray.count {
                json[appArguments.mainImage.long][i].dictionaryObject = observedDialogContent.imageArray[i].dictionary
            }
        }
                
        //print("Generated JSON")
        //convert the JSON to a raw String
        jsonFormattedOutout = json.rawString() ?? "json is nil"

        if debug {
            jsonFormattedOutout = jsonDEBUG.rawString() ?? ""
        }
        return jsonFormattedOutout
    }
    
    init (observedDialogContent : DialogUpdatableContent) {
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
    
    @ObservedObject var observedData : DialogUpdatableContent
    
    //@State var titleColour : Color
    // values being updated
    //@State var dialogTitle : String
    
    init(observedDialogContent : DialogUpdatableContent) {
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
            List() {
                Section(header: Text("Basic")) {
                    NavigationLink(destination: CKBasicsView(observedDialogContent: observedData)){
                        Text("Content")
                    }
                    NavigationLink(destination: CKWindowProperties(observedDialogContent: observedData)){
                        Text("Window")
                    }
                    NavigationLink(destination: CKIconView(observedDialogContent: observedData)){
                        Text("Icon")
                    }
                    NavigationLink(destination: CKDataEntryView(observedDialogContent: observedData)){
                        Text("Data Entry")
                    }
                    NavigationLink(destination: CKButtonView(observedDialogContent: observedData)){
                        Text("Buttons")
                    }
                }
                Section(header: Text("Advanced")) {
                    NavigationLink(destination: CKListView(observedDialogContent: observedData)){
                        Text("List Items")
                    }
                    NavigationLink(destination: CKImageView(observedDialogContent: observedData)){
                        Text("Images")
                    }
                }
                Spacer()
                Section(header: Text("Output")) {
                    NavigationLink(destination: JSONView(observedDialogContent: observedData) ){
                        Text("JSON Output")
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
                Button("Quit") {
                    quitDialog(exitCode: observedData.appProperties.exit0.code)
                }
                Spacer()
                .disabled(false)
                Button("Export Command") {}
                    .disabled(true)
            }
        }
        .padding(20)
    }
}


