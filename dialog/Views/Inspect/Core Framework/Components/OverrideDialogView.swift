//
//  OverrideDialogView.swift
//  dialog
//
//  The override dialog Preset 6 shows for a step that has waited too long: mark it succeeded,
//  failed or skipped by hand.
//

import SwiftUI

// MARK: - Override Dialog View

struct OverrideDialogView: View {
    @Binding var isPresented: Bool
    let stepId: String
    let cancelButtonText: String
    let titleText: String
    let descriptionText: String
    let successText: String
    let failureText: String
    let skipText: String
    let onAction: (OverrideAction) -> Void

    @Environment(\.palette) private var palette

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
                    .foregroundStyle(palette.warning)

                Text(titleText)
                    .font(.system(size: 24, weight: .bold))

                Text(descriptionText)
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
                        Text(successText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(palette.success.opacity(0.1))
                    .foregroundStyle(palette.success)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: {
                    onAction(.failure)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text(failureText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(palette.error.opacity(0.1))
                    .foregroundStyle(palette.error)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: {
                    onAction(.skip)
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "forward.circle.fill")
                        Text(skipText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(palette.info.opacity(0.1))
                    .foregroundStyle(palette.info)
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
