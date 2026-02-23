//
//  DebouncedUpdater.swift
//  dialog
//
//  Created by Henry Stamerjohann on 19/7/2025.
//

import Foundation

/// Utility class for debouncing UI updates to improve performance
class DebouncedUpdater {
    private var workItems: [String: DispatchWorkItem] = [:]
    private let delay: TimeInterval
    private let queue: DispatchQueue
    
    /// Initialize debounced updater
    /// - Parameters:
    ///   - delay: Delay in seconds before executing the action (default: InspectConstants.debounceDelay)
    ///   - queue: Queue to execute the action on (default: main queue)
    init(delay: TimeInterval = InspectConstants.debounceDelay, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// Debounce an action with a specific key
    /// - Parameters:
    ///   - key: Unique key for this debounced action
    ///   - action: The action to execute after the delay
    func debounce(key: String, action: @escaping () -> Void) {
        // Cancel previous work item for this key
        workItems[key]?.cancel()
        
        // Create new work item
        let workItem = DispatchWorkItem {
            action()
            // Clean up the work item after execution
            self.workItems.removeValue(forKey: key)
        }
        
        // Store the work item
        workItems[key] = workItem
        
        // Schedule execution
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// Cancel all pending debounced actions
    func cancelAll() {
        for workItem in workItems.values {
            workItem.cancel()
        }
        workItems.removeAll()
    }
    
    /// Cancel a specific debounced action
    /// - Parameter key: The key of the action to cancel
    func cancel(key: String) {
        workItems[key]?.cancel()
        workItems.removeValue(forKey: key)
    }
    
    deinit {
        cancelAll()
    }
}
