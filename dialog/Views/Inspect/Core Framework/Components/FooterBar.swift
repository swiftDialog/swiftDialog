//
//  FooterBar.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 06/02/2026
//
//  Reusable footer bar component for Inspect presets
//  Consolidates common footer patterns with logo, step counter, and navigation buttons
//

import SwiftUI

// MARK: - Footer Bar View

/// Reusable footer bar for wizard-style layouts
/// Includes optional logo, step counter, and navigation buttons
struct FooterBar<LeadingContent: View, TrailingContent: View>: View {
    let leadingContent: LeadingContent?
    let trailingContent: TrailingContent
    let centerText: String?
    let backgroundColor: Color
    let verticalPadding: CGFloat

    init(
        centerText: String? = nil,
        backgroundColor: Color = Color(NSColor.windowBackgroundColor),
        verticalPadding: CGFloat = 12,
        @ViewBuilder trailing: () -> TrailingContent,
        @ViewBuilder leading: () -> LeadingContent
    ) {
        self.centerText = centerText
        self.backgroundColor = backgroundColor
        self.verticalPadding = verticalPadding
        self.trailingContent = trailing()
        self.leadingContent = leading()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Leading content (logo, text, etc.)
            if let leading = leadingContent {
                leading
                    .padding(.leading, 20)
            }

            Spacer()

            // Center text (step counter, etc.)
            if let text = centerText {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Trailing content (buttons)
            trailingContent
                .padding(.trailing, 20)
        }
        .padding(.vertical, verticalPadding)
        .background(backgroundColor)
    }
}

// Convenience initializer without leading content
extension FooterBar where LeadingContent == EmptyView {
    init(
        centerText: String? = nil,
        backgroundColor: Color = Color(NSColor.windowBackgroundColor),
        verticalPadding: CGFloat = 12,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.centerText = centerText
        self.backgroundColor = backgroundColor
        self.verticalPadding = verticalPadding
        self.trailingContent = trailing()
        self.leadingContent = nil
    }
}

// MARK: - Step Counter Footer

/// Footer bar with step counter and navigation buttons
struct StepFooterBar: View {
    let currentStep: Int
    let totalSteps: Int
    let backButtonText: String
    let continueButtonText: String
    let highlightColor: Color
    let canGoBack: Bool
    let isContinueDisabled: Bool
    let onBack: () -> Void
    let onContinue: () -> Void
    let onOptionClick: (() -> Void)?
    let scaleFactor: CGFloat

    init(
        currentStep: Int,
        totalSteps: Int,
        backButtonText: String = "Back",
        continueButtonText: String = "Continue",
        highlightColor: Color = .accentColor,
        canGoBack: Bool = true,
        isContinueDisabled: Bool = false,
        scaleFactor: CGFloat = 1.0,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onOptionClick: (() -> Void)? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.backButtonText = backButtonText
        self.continueButtonText = continueButtonText
        self.highlightColor = highlightColor
        self.canGoBack = canGoBack
        self.isContinueDisabled = isContinueDisabled
        self.scaleFactor = scaleFactor
        self.onBack = onBack
        self.onContinue = onContinue
        self.onOptionClick = onOptionClick
    }

    var body: some View {
        FooterBar(centerText: stepText) {
            HStack(spacing: 12) {
                if canGoBack {
                    Button(backButtonText) {
                        onBack()
                    }
                    .buttonStyle(.bordered)
                }

                Button(continueButtonText) {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(highlightColor)
                .disabled(isContinueDisabled)
            }
        }
    }

    private var stepText: String {
        "Step \(currentStep + 1) of \(totalSteps)"
    }
}

// MARK: - Logo Footer Bar

/// Footer bar with optional text, step counter, and navigation buttons
/// For logo images, use the generic FooterBar with custom leading content
struct LogoFooterBar: View {
    let logoText: String?
    let currentStep: Int
    let totalSteps: Int
    let backButtonText: String
    let continueButtonText: String
    let highlightColor: Color
    let canGoBack: Bool
    let isContinueDisabled: Bool
    let scaleFactor: CGFloat
    let onBack: () -> Void
    let onContinue: () -> Void

    init(
        logoText: String? = nil,
        currentStep: Int,
        totalSteps: Int,
        backButtonText: String = "Back",
        continueButtonText: String = "Continue",
        highlightColor: Color = .accentColor,
        canGoBack: Bool = true,
        isContinueDisabled: Bool = false,
        scaleFactor: CGFloat = 1.0,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.logoText = logoText
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.backButtonText = backButtonText
        self.continueButtonText = continueButtonText
        self.highlightColor = highlightColor
        self.canGoBack = canGoBack
        self.isContinueDisabled = isContinueDisabled
        self.scaleFactor = scaleFactor
        self.onBack = onBack
        self.onContinue = onContinue
    }

    var body: some View {
        FooterBar(centerText: stepText) {
            // Buttons
            HStack(spacing: 12) {
                if canGoBack {
                    Button(backButtonText) {
                        onBack()
                    }
                    .buttonStyle(.bordered)
                }

                Button(continueButtonText) {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(highlightColor)
                .disabled(isContinueDisabled)
            }
        } leading: {
            // Logo text area (for logo images, use the generic FooterBar with custom leading content)
            if let text = logoText {
                Text(text)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stepText: String {
        "Step \(currentStep + 1) of \(totalSteps)"
    }
}

// MARK: - Simple Button Footer

/// Simple footer with just buttons (no step counter)
struct SimpleButtonFooter: View {
    let primaryText: String
    let secondaryText: String?
    let highlightColor: Color
    let isPrimaryDisabled: Bool
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    init(
        primaryText: String,
        secondaryText: String? = nil,
        highlightColor: Color = .accentColor,
        isPrimaryDisabled: Bool = false,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.highlightColor = highlightColor
        self.isPrimaryDisabled = isPrimaryDisabled
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        FooterBar {
            HStack(spacing: 12) {
                if let secondary = secondaryText, let action = onSecondary {
                    Button(secondary) {
                        action()
                    }
                    .buttonStyle(.bordered)
                }

                Button(primaryText) {
                    onPrimary()
                }
                .buttonStyle(.borderedProminent)
                .tint(highlightColor)
                .disabled(isPrimaryDisabled)
            }
        }
    }
}
