//
//  CKHelpView.swift
//  dialog
//
//  Created by Bart Reardon on 22/10/2025.
//


import SwiftUI

struct CKHelpView: View {
    
    var text: String?
    
    var body: some View {
        Text(text ?? "No help available")
            .multilineTextAlignment(.leading)
            .padding(20)
    }
}
