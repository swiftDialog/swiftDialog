//
//  OverrideDialogView.swift
//  dialog
//
//  Shared override dialog for processing step overrides.
//  Used by Preset6 and Preset5 when a processing step has been waiting
//  for an extended period and the user wants to manually override the result.
//

import SwiftUI

// MARK: - Override Dialog View

struct OverrideDialogView: View {
    @Binding var isPresented: Bool
    let stepId: String
    let cancelButtonText: String
    let onAction: (OverrideAction) -> Void

    enum OverrideAction {
        case success
        case failure
        case skip
        case cancel
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Override Step")
                    .font(.system(size: 24, weight: .bold))

                Text("This step has been waiting for an extended period. How would you like to proceed?")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    onAction(.success)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Success")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: {
                    onAction(.failure)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Mark as Failed")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: {
                    onAction(.skip)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "forward.circle.fill")
                        Text("Skip This Step")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // Cancel button
            Button(cancelButtonText) {
                onAction(.cancel)
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 16))
        .shadow(radius: 20)
    }
}
