//
//  CKSelectLists.swift
//  dialog
//
//  Created by Bart Reardon on 22/10/2025.
//

import SwiftUI

struct CKSelectListsView: View {

    @ObservedObject var observedData: DialogUpdatableContent

    @State private var showHelp: Bool = false

    init(observedDialogContent: DialogUpdatableContent) {
        self.observedData = observedDialogContent
    }

    var body: some View {
        
        LabelView(label: "Select Lists".localized)
        HStack {
            Button(action: {
                showHelp.toggle()
            }, label: {
                Image.init(systemName: "questionmark.app.fill")
            })
            .popover(isPresented: $showHelp) {
                let sdHelp = SDHelp(arguments: observedData.args)
                CKHelpView(text: sdHelp.argument.dropdownTitle.helpLong)
            }
            
            
            Button(action: {
                userInputState.dropdownItems.append(DropDownItems(title: "New Item", values: [], defaultValue: ""))
                observedData.dropdownArray.append(DropDownItems(title: "New Item", values: [], defaultValue: ""))
                observedData.args.dropdownTitle.present = true
                appArguments.dropdownTitle.present = true
            }, label: {
                Image(systemName: "plus")
            })
            Toggle("Show".localized, isOn: $observedData.args.dropdownTitle.present)
                .toggleStyle(.switch)

            //Button("Clear All") {
            //    observedData.listItemPresent = false
            //    observedData.listItemsArray = [ListItems]()
            //}

            Spacer()
        }
        .padding(20)
        
        ScrollView {
            //List {
            ForEach(0..<userInputState.dropdownItems.count, id: \.self) { item in
                Text("\(userInputState.dropdownItems[item].title)")
            }
        }

    }
}

