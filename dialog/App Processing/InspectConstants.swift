//
//  InspectConstants.swift
//  dialog
//
//  Created by Henry Stamerjohann on 19/7/2025.
//

import Foundation

/// Central configuration constants for inspect functionality
struct InspectConstants {
    // MARK: - File Paths
    static let commandFilePath = "/var/tmp/dialog.log"
    static let tempConfigPath = "/tmp/appmonitor_config.json"
    static let applicationsPath = "/Applications"
    static let libraryApplicationSupportPath = "/Library/Application Support"
    
    // MARK: - Timing Configuration
    static let fallbackTimerInterval: TimeInterval = 30.0
    static let fsEventsLatency: TimeInterval = 0.1
    static let cacheTimeout: TimeInterval = 60.0  // Increased from 10s to reduce memory churn
    static let debounceDelay: TimeInterval = 0.1
    static let updateTimerInterval: TimeInterval = 5.0
    static let fileSystemCheckInterval: TimeInterval = 3.0
    static let robustUpdateInterval: TimeInterval = 2.0
    
    // MARK: - UI Animation
    static let standardAnimationDuration: TimeInterval = 0.3
    static let longAnimationDuration: TimeInterval = 0.5
    static let scaleAnimationDuration: TimeInterval = 0.2
    
    // MARK: - Performance Limits
    static let maxRetryAttempts = 3
    static let maxCacheEntries = 100
    static let maxMemoryUsage = 10_000_000 // 10MB
    
    // MARK: - UI Layout
    static let sideMessageInterval: TimeInterval = 10.0
    static let progressCompletionDelay: TimeInterval = 2.0
    
    // MARK: - UI Scale Factors
    static let miniScaleFactor: CGFloat = 0.75
    static let defaultScaleFactor: CGFloat = 1.0
    
    // MARK: - Additional Delays
    static let manualScrollTimeoutInterval: TimeInterval = 5.0
    static let buttonStateUpdateDelay: TimeInterval = 1.0
    static let retryMonitoringDelay: TimeInterval = 0.5
    static let startupDelay: TimeInterval = 1.0
    
    // MARK: - Monitoring Configuration
    static let inspectQueueQoS = DispatchQoS.background
    static let inspectQueueLabel = "app.inspect"
}
