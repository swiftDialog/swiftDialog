//
//  InspectState+JsonMonitors.swift
//  dialog
//
//  Manual recheck of the plist monitors (`plistMonitors`).
//

import SwiftUI

extension InspectState {
    /// Rechecks an item's plist monitors now. Monitor keys are "itemId_monitor_N".
    /// - Parameter onUpdate: called per changed value with (itemId, guidanceBlockIndex,
    ///   targetProperty, newValue).
    @MainActor
    func recheckPlistMonitorsForItem(_ itemId: String, onUpdate: @escaping (String, Int, String, String) -> Void) {
        let monitorKeys = plistMonitors.keys.filter { $0.hasPrefix("\(itemId)_monitor_") }

        guard !monitorKeys.isEmpty else {
            writeLog("InspectState: No monitors found for item '\(itemId)' to recheck", logLevel: .debug)
            return
        }

        writeLog("InspectState: Manual recheck triggered for '\(itemId)' (\(monitorKeys.count) monitor(s))", logLevel: .info)

        guard let item = items.first(where: { $0.id == itemId }),
              let monitors = item.plistMonitors else {
            writeLog("InspectState: Item '\(itemId)' not found or has no plistMonitors", logLevel: .error)
            return
        }

        for (monitorIndex, monitor) in monitors.enumerated() {
            let monitorKey = "\(itemId)_monitor_\(monitorIndex)"

            guard let storedMonitor = plistMonitors[monitorKey] else {
                continue
            }

            let useUserDefaults = monitor.useUserDefaults == true

            let currentValue = readPlistMonitorValue(monitor: monitor, useUserDefaults: useUserDefaults)
            let lastValue = storedMonitor.currentValue

            if currentValue != lastValue {
                writeLog("InspectState: Manual recheck detected change for '\(itemId)' monitor \(monitorIndex): \(lastValue) → \(currentValue)", logLevel: .info)

                let mappedValue = mapMonitorValue(currentValue, through: monitor.valueMap) ?? currentValue

                onUpdate(itemId, monitor.guidanceBlockIndex, monitor.targetProperty, mappedValue)

                plistMonitors[monitorKey] = PlistMonitorTask(
                    poll: storedMonitor.poll,
                    initialValue: storedMonitor.initialValue,
                    currentValue: currentValue,
                    recheckInterval: storedMonitor.recheckInterval
                )
            } else {
                writeLog("InspectState: Manual recheck for '\(itemId)' monitor \(monitorIndex): no change (value: \(currentValue))", logLevel: .debug)
            }
        }
    }

    /// Rechecks every active plist monitor now; `onUpdate` as in `recheckPlistMonitorsForItem`.
    @MainActor
    func recheckAllPlistMonitors(onUpdate: @escaping (String, Int, String, String) -> Void) {
        var itemIds = Set<String>()
        for monitorKey in plistMonitors.keys {
            // Item ids may themselves contain "_"; the key ends in "_monitor_N".
            let components = monitorKey.split(separator: "_")
            if components.count >= 3 {
                let itemId = components[0..<components.count-2].joined(separator: "_")
                itemIds.insert(itemId)
            }
        }

        guard !itemIds.isEmpty else {
            writeLog("InspectState: No active monitors to recheck", logLevel: .debug)
            return
        }

        writeLog("InspectState: Manual recheck triggered for ALL items (\(itemIds.count) item(s), \(plistMonitors.count) monitor(s))", logLevel: .info)

        for itemId in itemIds {
            recheckPlistMonitorsForItem(itemId, onUpdate: onUpdate)
        }
    }

}
