//
//  PseudoNotificationView.swift
//  dialog
//
//  Created for swiftDialog pseudo notification support.
//  Displays a custom notification-style window that slides in from the right.
//

import SwiftUI
import AppKit
import Combine
import Textual

// MARK: - Notification Style

enum PseudoNotificationStyle {
    case banner   // auto-dismisses after a timeout
    case alert    // stays until user interacts
}

// MARK: - Configuration

/// Bundles all parameters needed to display a pseudo notification.
struct PseudoNotificationConfig {
    var identifier: String = ""
    var icon: String = ""
    var title: String = ""
    var subtitle: String = ""
    var message: String = ""
    var imagePath: String = ""
    var button1Label: String = appDefaults.button1Default
    var button1Action: String = ""
    var button2Label: String = ""
    var button2Action: String = ""
    var style: PseudoNotificationStyle = .banner
    var soundEnabled: Bool = false
    var dismissTimerSeconds: Double = 6.0

    /// The action bar is shown when button2 has a label or an action.
    var showActionBar: Bool {
        !button2Label.isEmpty || !button2Action.isEmpty
    }
}

// MARK: - Distributed Notification Constants

private let pseudoDismissPrefix = "com.swiftdialog.pseudo.dismiss."
private let pseudoDismissAll = "com.swiftdialog.pseudo.dismiss.all"

/// Post a distributed notification to dismiss a pseudo notification by identifier.
func removePseudoNotification(identifier: String?) {
    if let id = identifier, !id.isEmpty {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(pseudoDismissPrefix + id),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    } else {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(pseudoDismissAll),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

// MARK: - PseudoNotificationView

struct PseudoNotificationView: View {
    let config: PseudoNotificationConfig
    let onDismiss: () -> Void
    let onClose: () -> Void
    let onButton2: (() -> Void)?

    @State private var isHovered = false
    @State private var elapsedMinutes: Int = 0

    private let appearDate = Date()
    private let notificationWidth: CGFloat = 345
    private let cornerRadius: CGFloat = 14

    private let timestampTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var timestampText: String {
        if elapsedMinutes < 1 {
            return "now"
        } else {
            return "\(elapsedMinutes)m ago"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content: icon on the left (vertically centered), all text on the right
            HStack(alignment: .center, spacing: 12) {
                // Icon — sole left-side element, centered vertically
                IconView(image: config.icon, corners: false)
                //notificationIcon
                    .frame(width: 40, height: 40)
                    //.clipShape(RoundedRectangle(cornerRadius: 8))

                // Right-side column: title, subtitle, message, image
                VStack(alignment: .leading, spacing: 4) {
                    // Title row with timestamp
                    HStack(alignment: .firstTextBaseline) {
                        Text(config.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Spacer()

                        Text(timestampText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if !config.subtitle.isEmpty {
                        Text(config.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if !config.message.isEmpty {
                        if let attributedString = try? AttributedString(
                            markdown: config.message,
                            options: AttributedString.MarkdownParsingOptions(
                                interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributedString)
                                .font(.system(size: 13))
                                .lineLimit(config.style == .alert ? 6 : 4)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(config.message)
                                .font(.system(size: 13))
                                .lineLimit(config.style == .alert ? 6 : 4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Attached image (if provided)
                    if !config.imagePath.isEmpty {
                        notificationImage
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Action bar — shown when button2 has a label or action
            if config.showActionBar {
                Divider()

                HStack(spacing: 0) {
                    // Button 1 (primary / dismiss action)
                    Button(action: {
                        onDismiss()
                    }) {
                        Text(config.button1Label)
                            .font(.system(size: 13, weight: .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    //.foregroundColor(.accentColor)

                    Divider()
                        .frame(height: 20)

                    // Button 2 (secondary action)
                    let b2Label = config.button2Label.isEmpty
                        ? appDefaults.button2Default
                        : config.button2Label
                    Button(action: {
                        onButton2?()
                    }) {
                        Text(b2Label)
                            .font(.system(size: 13, weight: .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    //.foregroundColor(.accentColor)
                }
            }
        }
        .frame(width: notificationWidth)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        //.shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .overlay(alignment: .topLeading) {
            if isHovered {
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                //.offset(x: -6, y: -6)
                .padding(4)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        //.padding(.top, 6)
        //.padding(.leading, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onReceive(timestampTimer) { _ in
            elapsedMinutes = max(1, Int(Date().timeIntervalSince(appearDate) / 60))
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var notificationIcon: some View {
        let iconValue = config.icon
        if iconValue.isEmpty || iconValue == "default" {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if iconValue.hasSuffix(".app") || iconValue.hasSuffix("prefPane") {
            Image(nsImage: getAppIcon(appPath: iconValue))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if iconValue.lowercased().hasPrefix("sf=") {
            let symbolName = String(iconValue.dropFirst(3))
                .components(separatedBy: ",").first ?? ""
            Image(systemName: symbolName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
                .padding(4)
        } else if iconValue.hasPrefix("http") || FileManager.default.fileExists(atPath: iconValue) {
            Image(nsImage: getImageFromPath(fileImagePath: iconValue, returnErrorImage: true))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    // MARK: - Attached Image

    @ViewBuilder
    private var notificationImage: some View {
        DisplayImage(config.imagePath, corners: true, rezize: true, content: .fit)
            .frame(maxHeight: 160)
    }
}

// MARK: - Window Controller

class PseudoNotificationWindowController {
    private var window: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var autoDismissTimer: Timer?
    private var dismissObservers: [NSObjectProtocol] = []

    deinit {
        for observer in dismissObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    /// Show the pseudo notification, sliding in from the right edge of the screen.
    func show(config: PseudoNotificationConfig) {
        DispatchQueue.main.async { [self] in
            // Listen for distributed dismiss notifications
            let center = DistributedNotificationCenter.default()

            // Always listen for "dismiss all"
            let allObserver = center.addObserver(
                forName: NSNotification.Name(pseudoDismissAll),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.slideOutAndQuit()
            }
            dismissObservers.append(allObserver)

            // Listen for identifier-specific dismiss if we have one
            let identifier = config.identifier.isEmpty ? UUID().uuidString : config.identifier
            let idObserver = center.addObserver(
                forName: NSNotification.Name(pseudoDismissPrefix + identifier),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.slideOutAndQuit()
            }
            dismissObservers.append(idObserver)
            let notificationWidth: CGFloat = 345
            let estimatedHeight: CGFloat = 120

            guard let screen = NSScreen.main else { return }
            let visibleFrame = screen.visibleFrame

            // Start position: just off the right edge, near the top
            let startX = visibleFrame.maxX + 10
            let topY = visibleFrame.maxY - estimatedHeight - 5

            let panel = NSPanel(
                contentRect: NSRect(x: startX, y: topY, width: notificationWidth, height: estimatedHeight),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            panel.isMovable = false
            panel.hidesOnDeactivate = false

            let capturedConfig = config
            let contentView = PseudoNotificationView(
                config: capturedConfig,
                onDismiss: { [weak self] in
                    self?.dismiss()
                    if !capturedConfig.button1Action.isEmpty {
                        notificationAction(capturedConfig.button1Action)
                    }
                    quitDialog(exitCode: 0)
                },
                onClose: { [weak self] in
                    self?.slideOutAndQuit()
                },
                onButton2: !capturedConfig.button2Action.isEmpty ? { [weak self] in
                    self?.dismiss()
                    notificationAction(capturedConfig.button2Action)
                    quitDialog(exitCode: 2)
                } : nil
            )

            let hosting = NSHostingView(rootView: AnyView(contentView))
            hosting.frame = panel.contentView!.bounds
            hosting.autoresizingMask = [.width, .height]
            panel.contentView?.addSubview(hosting)

            self.window = panel
            self.hostingView = hosting

            // Size to fit content (accounts for close-button padding)
            let fittingSize = hosting.fittingSize
            let finalWidth = max(fittingSize.width, notificationWidth)
            let finalHeight = max(fittingSize.height, estimatedHeight)
            let finalY = visibleFrame.maxY - finalHeight - 12
            panel.setFrame(
                NSRect(x: startX, y: finalY, width: finalWidth, height: finalHeight),
                display: true
            )

            panel.orderFrontRegardless()

            // Play sound if requested
            if config.soundEnabled {
                NSSound.beep()
            }

            // Slide in animation
            let endX = visibleFrame.maxX - finalWidth - 12
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(
                    NSRect(x: endX, y: finalY, width: finalWidth, height: finalHeight),
                    display: true
                )
            })

            // Auto-dismiss for banner style
            if config.style == .banner {
                autoDismissTimer = Timer.scheduledTimer(
                    withTimeInterval: config.dismissTimerSeconds,
                    repeats: false
                ) { [weak self] _ in
                    self?.slideOutAndQuit()
                }
            }
        }
    }

    /// Slide out to the right and quit.
    private func slideOutAndQuit() {
        guard let panel = window, let screen = NSScreen.main else {
            quitDialog(exitCode: 0)
            return
        }

        let offScreenX = screen.visibleFrame.maxX + 10
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(
                NSRect(x: offScreenX, y: panel.frame.origin.y,
                       width: panel.frame.width, height: panel.frame.height),
                display: true
            )
        }, completionHandler: {
            self.dismiss()
            quitDialog(exitCode: 0)
        })
    }

    /// Remove the window immediately.
    private func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Public entry point

/// Sends a pseudo notification that renders as a custom SwiftUI window.
/// Pre-fetches any remote resources before displaying so the window sizes correctly
/// and we don't end up with an invisible orphaned process.
func sendPseudoNotification(config: PseudoNotificationConfig) {
    let controller = PseudoNotificationWindowController()
    // Keep a strong reference so it doesn't get deallocated
    pseudoNotificationController = controller

    // Pre-fetch remote resources on a background thread so the window
    // is created only after images are available (avoids sizing issues
    // and orphaned processes when AsyncImage loads slowly).
    DispatchQueue.global(qos: .userInitiated).async {
        // Pre-warm icon if it's a URL or file path that needs loading
        if !config.icon.isEmpty && !config.icon.lowercased().hasPrefix("sf=")
            && config.icon != "default" && !config.icon.hasSuffix(".app")
            && !config.icon.hasSuffix("prefPane") {
            _ = getImageFromPath(fileImagePath: config.icon, returnErrorImage: true)
        }

        // Pre-warm attached image
        if !config.imagePath.isEmpty {
            _ = getImageFromPath(fileImagePath: config.imagePath, returnErrorImage: true)
        }

        // Now show on main thread — resources are cached and ready
        DispatchQueue.main.async {
            controller.show(config: config)
        }
    }
}

/// Global reference to keep the window controller alive.
private var pseudoNotificationController: PseudoNotificationWindowController?
