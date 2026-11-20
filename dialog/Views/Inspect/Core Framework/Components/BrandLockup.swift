//
//  BrandLockup.swift
//  dialog
//
//  The footer's two-brand line (customer mark · name · divider · attribution · vendor mark) for
//  `ProvisioningShell.lockup(_:)`. Resolves nothing: inputs arrive appearance-resolved.

import SwiftUI

/// The customer mark in the footer lockup, in the same 24pt box as the vendor mark.
/// A logo draws at box height, an SF Symbol is tinted; wordmark and swatch rungs draw nothing,
/// since the lockup already prints the name beside the box.
struct ProvisioningLockupMark: View {
    let identity: ProvisioningIdentity

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch identity {
        case .mark(let path):
            BrandMark(path: darkVariantImagePath(path, dark: colorScheme == .dark),
                      box: BrandMarkBox(height: ProvisioningM.lockupMarkSize, maxWidth: nil))
        case .symbol(let name, let color):
            // Tinted, not filled: a filled tile would outweigh the vendor wordmark beside it.
            Image(systemName: name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: ProvisioningM.lockupMarkSize, height: ProvisioningM.lockupMarkSize)
        case .wordmark:
            // Nothing: the lockup prints the customer's name right beside this box.
            EmptyView()
        case .swatch:
            // Nothing, as for the wordmark rung.
            EmptyView()
        }
    }
}


/// The two-brand footer line: a 24pt box, an 11pt gap, and a divider drawn only when something follows it.
struct BrandLockup: View {
    let customer: ProvisioningIdentity?
    let name: String
    let attribution: String?
    let vendorPath: String?
    var markBox: CGFloat = ProvisioningM.lockupMarkSize
    var gap: CGFloat = ProvisioningM.lockupGap

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: gap) {
            if let customer { ProvisioningLockupMark(identity: customer) }
            Text(name)
                .font(.system(size: ProvisioningM.lockupNameSize, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
            if vendorPath != nil || attribution != nil {
                Rectangle()
                    .fill(palette.text.opacity(0.14))
                    .frame(width: 0.5, height: ProvisioningM.lockupDividerHeight)
            }
            if let attribution {
                Text(attribution)
                    .font(.system(size: ProvisioningM.lockupAttributionSize))
                    .foregroundStyle(palette.textFaint)
                    .lineLimit(1)
            }
            if let vendorPath {
                BrandMark(path: vendorPath, box: BrandMarkBox(height: markBox, maxWidth: nil))
            }
        }
        // Keep ideal width: as the lowest-priority child in `FooterRow`, the text would otherwise get zero width.
        .fixedSize(horizontal: true, vertical: false)
    }
}
