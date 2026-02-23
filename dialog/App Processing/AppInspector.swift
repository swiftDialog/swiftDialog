//
//  AppInspector.swift
//  dialog
//
//  Created by Henry Stamerjohann on 19/7/2025.
//

import Foundation

// MARK: - Protocol Definitions for Dependency Injection
protocol FileSystemMonitorProtocol {
    func startMonitoring(paths: [String])
    func stopMonitoring()
}

protocol CommandFileWriterProtocol {
    func writeCommand(_ command: String)
}

// MARK: - AppInspector: Real-time filesystem monitoring for monitor mode
class AppInspector {
    struct AppConfig: Codable {
        struct App: Codable {
            let id: String
            let displayName: String
            let guiIndex: Int
            let paths: [String]
        }
        let apps: [App]
        let cachePaths: [String]?
    }
    
    // MARK: - Properties
    private var config: AppConfig?
    private var lastStatus: [String: Bool] = [:]
    private var lastCachedStatus: [String: Bool] = [:]
    private let checkInterval: TimeInterval = 2.0
    private let commandFile: String
    private var fsEventStream: FSEventStreamRef?
    private let fileSystemCache = FileSystemCache()
    
    // MARK: - Initialization
    init(commandFile: String = InspectConstants.commandFilePath) {
        self.commandFile = commandFile
        initCommandFile()
    }
    
    // MARK: - Private Methods
    private func initCommandFile() {
        // Ensure we have the absolute path for the command file
        let absolutePath = commandFile.hasPrefix("/") ? commandFile : InspectConstants.commandFilePath
        
        // Ensure command file exists and is writable
        FileManager.default.createFile(atPath: absolutePath, contents: nil, attributes: [
            .posixPermissions: 0o666
        ])
        writeLog("AppInspector: Initialized command file at \(absolutePath)", logLevel: .debug)
    }
    
    private func writeCommand(_ command: String) {
        // Ensure we have the absolute path for the command file
        let absolutePath = commandFile.hasPrefix("/") ? commandFile : InspectConstants.commandFilePath
        
        do {
            let data = (command + "\n").data(using: .utf8)!
            let url = URL(fileURLWithPath: absolutePath)
            
            if FileManager.default.fileExists(atPath: absolutePath) {
                let fileHandle = try FileHandle(forWritingTo: url)
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } else {
                try data.write(to: url)
            }
            writeLog("AppInspector: Command written to \(absolutePath): \(command)", logLevel: .debug)
        } catch {
            writeLog("AppInspector: Failed to write command to \(absolutePath): \(error)", logLevel: .error)
        }
    }
    
    private func checkInstalled(_ paths: [String]) -> Bool {
        for path in paths where FileManager.default.fileExists(atPath: path) {
                return true
            }
        return false
    }
    
    private func checkCacheForApp(_ app: AppConfig.App) -> Bool {
        guard let cachePaths = config?.cachePaths else { return false }
        
        let appIdLower = app.id.lowercased()
        let appNameLower = app.displayName.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Use the optimized containsMatchingFile method to avoid unnecessary memory allocations  
        for cachePath in cachePaths {
            let hasMatchingFile = fileSystemCache.containsMatchingFile(in: cachePath) { file in
                let lowercaseFile = file.lowercased()
                let appIdMatch = lowercaseFile.contains(appIdLower)
                let nameMatch = lowercaseFile.contains(appNameLower)
                let isDownloadFile = lowercaseFile.hasSuffix(".download") || 
                                    lowercaseFile.hasSuffix(".pkg") || 
                                    lowercaseFile.hasSuffix(".dmg")
                
                return (appIdMatch || nameMatch) && isDownloadFile
            }
            
            if hasMatchingFile {
                return true
            }
        }
        return false
    }
    
    private func checkAndReport() {
        guard let apps = config?.apps else { return }
        
        var totalInstalled = 0
        var changes: [(index: Int, name: String, installed: Bool, cached: Bool)] = []
        
        for app in apps {
            let isInstalled = checkInstalled(app.paths)
            let isCached = checkCacheForApp(app)
            let wasInstalled = lastStatus[app.id] ?? false
            let wasCached = lastCachedStatus[app.id] ?? false
            
            if isInstalled {
                totalInstalled += 1
            }
            
            // Report installation status changes
            if isInstalled != wasInstalled {
                changes.append((app.guiIndex, app.displayName, isInstalled, isCached))
                lastStatus[app.id] = isInstalled
            }
            
            // Report cache status changes (downloads starting/stopping)
            if isCached != wasCached && !isInstalled {
                changes.append((app.guiIndex, app.displayName, false, isCached))
                lastCachedStatus[app.id] = isCached
            }
        }
        
        // Write dialog commands for status updates
        for change in changes {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeStr = formatter.string(from: Date())
            
            if change.installed {
                writeCommand("listitem: index: \(change.index), status: success, statustext: Installed (\(timeStr))")
                writeCommand("progresstext: \(change.name) successfully installed")
                writeCommand("progress: increment")
                writeLog("AppInspector: INSTALLED \(change.name)", logLevel: .info)
            } else if change.cached {
                writeCommand("listitem: index: \(change.index), status: wait, statustext: Downloading...")
                writeCommand("progresstext: \(change.name) downloading")
                writeLog("AppInspector: DOWNLOADING \(change.name)", logLevel: .info)
            } else {
                writeCommand("listitem: index: \(change.index), status: pending, statustext: Pending")
                writeLog("AppInspector: PENDING \(change.name)", logLevel: .info)
            }
        }
        
        // Check if complete
        if totalInstalled == apps.count {
            writeCommand("progresstext: All applications successfully installed!")
            writeCommand("progress: complete")
            writeLog("AppInspector: All applications installed", logLevel: .info)
        }
    }
    
    private func setupFSEvents() {
        var pathsToMonitor = [InspectConstants.applicationsPath, InspectConstants.libraryApplicationSupportPath]
        
        // Add cache paths from config
        if let cachePaths = config?.cachePaths {
            pathsToMonitor.append(contentsOf: cachePaths)
        }
        
        // Filter to existing paths
        let existingPaths = pathsToMonitor.filter { FileManager.default.fileExists(atPath: $0) }
        
        writeLog("AppInspector: Monitoring \(existingPaths.count) filesystem paths", logLevel: .debug)
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            if let info = clientCallBackInfo {
                let monitor = Unmanaged<AppInspector>.fromOpaque(info).takeUnretainedValue()
                // Trigger immediate check on filesystem change
                DispatchQueue.main.async {
                    monitor.checkAndReport()
                }
            }
        }
        
        if let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            existingPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            InspectConstants.fsEventsLatency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) {
            // TODO: remove following comments once behaviour is verified
            // following generates a warning
            // 'FSEventStreamScheduleWithRunLoop' was deprecated in macOS 13.0: Use FSEventStreamSetDispatchQueue instead.
            // FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            let queue = DispatchQueue(label: bundleID + ".fsEventStream")
            FSEventStreamSetDispatchQueue(stream, queue)

            
            FSEventStreamStart(stream)
            fsEventStream = stream
        }
    }
    
    // MARK: - Public Interface
    func loadConfig(from jsonPath: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let loadedConfig = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            writeLog("AppInspector: Could not load config from \(jsonPath)", logLevel: .error)
            return
        }
        
        config = loadedConfig
        writeLog("AppInspector: Loaded \(loadedConfig.apps.count) apps from config", logLevel: .info)
    }
    
    func start() {
        guard config != nil else {
            writeLog("AppInspector: No config loaded, cannot start monitoring", logLevel: .error)
            return
        }
        
        writeLog("AppInspector: Starting filesystem monitoring", logLevel: .info)
        
        // Initial check
        checkAndReport()
        
        // Setup periodic checks
        Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkAndReport()
        }
        
        // Setup FSEvents for real-time detection
        setupFSEvents()
    }
    
    // MARK: - Cleanup
    deinit {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
