//
//  InspectLayoutProtocol.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/07/2025
//

import SwiftUI

// MARK: - Protocol Definition

protocol InspectLayoutProtocol {
    associatedtype Body: View

    var inspectState: InspectState { get }

    @ViewBuilder var body: Body { get }
}

// MARK: - Protocol Extension

extension InspectLayoutProtocol {

    // MARK: Properties

    var scaleFactor: CGFloat {
        // Use size mode instead of isMini
        let sizeMode = inspectState.uiConfiguration.size ?? "standard"
        switch sizeMode {
        case "compact": return 0.85
        case "large": return 1.15
        case "assistant": return 0.95  // Slightly scaled down from standard (1024 vs 1100 width)
        case "setup": return 0.80         // Apple Setup Assistant (800×600)
        default: return 1.0  // standard
        }
    }

    // MARK: Window Size Management

    /// Returns the appropriate window size based on configuration and preset requirements
    var windowSize: CGSize {
        // First check for explicit width/height overrides
        if let width = inspectState.uiConfiguration.width,
           let height = inspectState.uiConfiguration.height {
            return CGSize(width: CGFloat(width), height: CGFloat(height))
        }

        // Get the size mode and preset
        let sizeMode = inspectState.uiConfiguration.size ?? "standard"
        let presetName = inspectState.uiConfiguration.preset

        // Use shared sizing definitions
        let (width, height) = InspectSizes.getSize(preset: presetName, mode: sizeMode)
        return CGSize(width: width, height: height)
    }

    /// Get the current size mode
    var sizeMode: String {
        return inspectState.uiConfiguration.size ?? "standard"
    }

    // MARK: Common UI Dimensions

    var standardPadding: CGFloat {
        return 20 * scaleFactor
    }

    var itemSpacing: CGFloat {
        return 12 * scaleFactor
    }

    var iconSize: CGFloat {
        return CGFloat(inspectState.uiConfiguration.iconSize) * scaleFactor
    }

    // MARK: Item Sorting
    
    func getSortedItemsByStatus() -> [InspectConfig.ItemConfig] {
        let completedItems = inspectState.items.filter { inspectState.completedItems.contains($0.id) }
        let downloadingItems = inspectState.items.filter { inspectState.downloadingItems.contains($0.id) }
        let pendingItems = inspectState.items.filter { 
            !inspectState.completedItems.contains($0.id) && !inspectState.downloadingItems.contains($0.id) 
        }
        
        return completedItems + downloadingItems + pendingItems
    }
    
    func getItemStatusType(for item: InspectConfig.ItemConfig) -> InspectItemStatus {
        if inspectState.completedItems.contains(item.id) {
            return .completed
        } else if inspectState.downloadingItems.contains(item.id) {
            return .downloading
        } else {
            return .pending
        }
    }
    
    /// Returns the display text for an item's current status
    /// 
    /// Uses a three-tier customization system:
    /// 1. Item-specific status text (highest priority)
    /// 2. Global UILabels configuration 
    /// 3. Default hardcoded text (fallback)
    ///
    /// This allows for both global customization (e.g., changing "Installed" to "Complete" app-wide)
    /// and item-specific customization (e.g., different terminology for different workflow types)
    func getItemStatus(for item: InspectConfig.ItemConfig) -> String {
        if inspectState.completedItems.contains(item.id) {
            // Priority: log monitor (completion messages only) > item-specific > global UILabels > default
            // Skip stale "Installing..." / "Downloading..." statuses left over from the install phase
            if let logStatus = inspectState.logMonitorStatuses[item.id],
               logStatus.hasPrefix("Completed") || logStatus.hasPrefix("Installed") {
                return logStatus
            } else if let customStatus = item.completedStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.completedStatus {
                return globalStatus
            } else {
                return "Completed"
            }
        } else if inspectState.failedItems.contains(item.id) {
            // Priority: log monitor > global UILabels > default
            if let logStatus = inspectState.logMonitorStatuses[item.id] {
                return logStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.failedStatus {
                return globalStatus
            } else {
                return "Failed"
            }
        } else if inspectState.downloadingItems.contains(item.id) {
            // Priority: log monitor > item-specific > global UILabels > default
            if let logStatus = inspectState.logMonitorStatuses[item.id] {
                return logStatus
            } else if let customStatus = item.downloadingStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.downloadingStatus {
                return globalStatus
            } else {
                return "Installing..."
            }
        } else {
            // Pending: log monitor > item-specific > global UILabels > default
            if let logStatus = inspectState.logMonitorStatuses[item.id] {
                return logStatus
            } else if let customStatus = item.pendingStatus {
                return customStatus
            } else if let globalStatus = inspectState.config?.uiLabels?.pendingStatus {
                return globalStatus
            } else {
                return "Waiting"
            }
        }
    }
    
    // MARK: UI Components
    
    @ViewBuilder
    func buttonArea() -> some View {
        HStack(spacing: 12) {
            if (inspectState.configurationSource == .testData || inspectState.completedItems.count == inspectState.items.count) &&
               inspectState.buttonConfiguration.button2Visible && !inspectState.buttonConfiguration.button2Text.isEmpty {
                Button(inspectState.buttonConfiguration.button2Text) {
                    // Check if we're in demo mode and button says "Create Config"
                    if inspectState.configurationSource == .testData && inspectState.buttonConfiguration.button2Text == "Create Config" {
                        writeLog("InspectView: Creating sample configuration", logLevel: .info)
                        inspectState.createSampleConfiguration()
                    } else {
                        writeLog("InspectView: User clicked button2 (\(inspectState.buttonConfiguration.button2Text)) - exiting with code 2", logLevel: .info)
                        exit(2)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                // Note: button2 is always enabled when visible
            }
            
            Button(inspectState.buttonConfiguration.button1Text) {
                writeLog("InspectView: User clicked button1 (\(inspectState.buttonConfiguration.button1Text)) - exiting with code 0", logLevel: .info)
                exit(0)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(inspectState.buttonConfiguration.button1Disabled)
        }
    }
    
    @ViewBuilder
    func itemIcon(for item: InspectConfig.ItemConfig, size: CGFloat) -> some View {
        IconView(image: item.icon ?? "app.fill")
            .frame(width: size, height: size)
        /*
        if let iconPath = item.icon,
           FileManager.default.fileExists(atPath: iconPath) {
            Image(nsImage: NSImage(contentsOfFile: iconPath) ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.75))
                .foregroundStyle(.blue)
                .frame(width: size, height: size)
        }
         */
    }
    
    @ViewBuilder
    func statusIndicator(for item: InspectConfig.ItemConfig) -> some View {
        if inspectState.completedItems.contains(item.id) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 20 * scaleFactor))
        } else if inspectState.downloadingItems.contains(item.id) {
            ProgressView()
                .scaleEffect(0.8 * scaleFactor)
                .frame(width: 20 * scaleFactor, height: 20 * scaleFactor)
        } else {
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 20 * scaleFactor, height: 20 * scaleFactor)
        }
    }

    // MARK: Common Layout Components

    @ViewBuilder
    func standardItemRow(for item: InspectConfig.ItemConfig, showIcon: Bool = true) -> some View {
        HStack(spacing: itemSpacing) {
            if showIcon {
                itemIcon(for: item, size: 32 * scaleFactor)
            }

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(item.displayName)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)

                Text(getItemStatus(for: item))
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusIndicator(for: item)
        }
        .padding(.horizontal, standardPadding)
        .padding(.vertical, 8 * scaleFactor)
    }

    @ViewBuilder
    func progressBar(width: CGFloat? = nil) -> some View {
        if !inspectState.items.isEmpty {
            let progress = Double(inspectState.completedItems.count) / Double(inspectState.items.count)
            VStack(spacing: 4 * scaleFactor) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: width ?? 200 * scaleFactor)

                Text("\(inspectState.completedItems.count) of \(inspectState.items.count) completed")
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Supporting Types
// ItemStatusType enum removed - now using unified InspectItemStatus from InspectConfig.swift
