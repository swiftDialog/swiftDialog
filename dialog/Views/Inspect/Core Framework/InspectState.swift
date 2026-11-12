//
//  InspectState.swift
//  dialog
//
//  The shared observable model behind every inspect preset: loaded config, item and step
//  status sets, and the file, command-file and log monitors that feed them. Main actor.
//

import Foundation
import SwiftUI
import Combine

enum LoadingState: Equatable {
    case loading
    case loaded
    case failed(String)
}

// MARK: - Form Input State Structure

/// Form input values for one step's guidance content, keyed by control id.
/// Rides inside `Preset6State` onto the persistence queue, so it stays `Sendable`.
struct GuidanceFormInputState: Codable, Sendable {
    var checkboxes: [String: Bool] = [:]
    var dropdowns: [String: String] = [:]
    var radios: [String: String] = [:]
    var toggles: [String: Bool] = [:]
    var sliders: [String: Double] = [:]
    var textfields: [String: String] = [:]
    // Confirm-mode re-entries stay out of the six dictionaries above: result files, templates and
    // inherit refs iterate those, so a re-entered (possibly secure) value never reaches an output.
    var confirmations: [String: String] = [:]
}

@MainActor
class InspectState: ObservableObject, FileMonitorDelegate, @MainActor CadenceContext {
    // MARK: - Core State
    @Published var loadingState: LoadingState = .loading
    /// Current page inside each card step, keyed by step id. Kept here, not in view state, so it
    /// survives re-renders; reset when the step's Continue fires.
    @Published var cardSubStepIndex: [String: Int] = [:]
    /// Chosen editor per export step, keyed by step id; the action bar label follows it.
    @Published var exportEditorSelection: [String: String] = [:]
    @Published var items: [InspectConfig.ItemConfig] = []
    /// Rows added while running (`listitem: add`): shown, never counted toward completion.
    /// `trackedItems`, `trackedCompletedCount` and `trackedFailedCount` exclude them.
    @Published var addedItemIDs: Set<String> = []
    /// Per-row icon set while running (`itemicon:<id>:<path or URL>`); wins over the config's icon.
    /// Every resolver checks it first; an empty value clears it.
    @Published var itemIconOverrides: [String: String] = [:]
    /// Preset 6's root list typed as steps. Presets 1-4 keep `items`.
    @Published var steps: [InspectConfig.IntroStep] = []
    @Published var config: InspectConfig?
    /// Why the last save of a watched config (`"watch": true`) did not load; the last good config
    /// stays on screen.
    @Published var reloadIssue: String?
    private var configWatchTimer: Timer?
    private var watchedModification: Date?
    /// Watches the look's configuration profile off the main thread.
    private var profileWatch: ProfileLookWatch?
    /// The profile dictionary this dialog runs (`Config.flowKey`); nil means brand only.
    private var watchedFlow: String?

    // MARK: - Debug Mode

    /// Whether presets skip steps completed in an earlier launch. True only when the config sets
    /// `resumable: true` and no debug switch is on: `--debug`, `--inspect-mode`,
    /// `DIALOG_DEBUG_MODE` in the environment, or `debugMode: true` in the config.
    var shouldSkipCompletedSteps: Bool {
        guard config?.resumable == true else {
            writeLog("InspectState: Resumable mode not enabled, always fresh start", logLevel: .debug)
            return false
        }

        if appvars.debugMode {
            writeLog("InspectState: Debug mode enabled via --debug CLI flag", logLevel: .info)
            return false
        }
        if !appvars.inspectConfigPath.isEmpty {
            writeLog("InspectState: Debug mode enabled via --inspect-mode (always fresh start)", logLevel: .info)
            return false
        }
        if ProcessInfo.processInfo.environment["DIALOG_DEBUG_MODE"] != nil {
            writeLog("InspectState: Debug mode enabled via DIALOG_DEBUG_MODE environment variable", logLevel: .info)
            return false
        }
        if config?.debugMode == true {
            writeLog("InspectState: Debug mode enabled via config debugMode: true", logLevel: .info)
            return false
        }
        return true
    }

    // MARK: - Grouped Configuration State
    @Published var uiConfiguration = UIConfiguration()
    @Published var backgroundConfiguration = BackgroundConfiguration()
    @Published var buttonConfiguration = ButtonConfiguration()
    
    // MARK: - Preset-specific State
    @Published var plistSources: [InspectConfig.PlistSourceConfig]?
    @Published var colorThresholds = InspectConfig.ColorThresholds.default
    @Published var plistValidationResults: [String: Bool] = [:]

    // MARK: - Pre-cache Progress
    @Published var preCacheProgress: (loaded: Int, total: Int)?  // nil until the pre-cache starts

    // MARK: - Plist Monitoring
    var plistMonitors: [String: PlistMonitorTask] = [:]

    /// One plist poll with its baseline and last-seen value.
    struct PlistMonitorTask {
        let poll: Poll
        let initialValue: String
        let currentValue: String
        let recheckInterval: Int
    }

    // MARK: - View-specific State
    @Published var scrollOffset: Int = 0 // preset 3
    @Published var lastManualScrollTime: Date?
    
    // MARK: - Dynamic State
    // Every completion source writes these sets directly, so the primary button is re-checked here.
    @Published var completedItems: Set<String> = [] { didSet { requiredItemsChanged() } }
    @Published var downloadingItems: Set<String> = []
    @Published var failedItems: Set<String> = [] { didSet { requiredItemsChanged() } }
    @Published var itemProgress: [String: Int] = [:]  // 0-100, from `progress:<id>:<pct>`
    // `next`/`prev` IPC as a cumulative counter so queued signals coalesce; PhaseContainer takes the delta.
    @Published var phaseStepRequest: Int = 0

    // MARK: - Wallpaper Selection (preset 6)
    @Published var wallpaperSelection: [String: String] = [:]  // selectionKey → full image path

    // MARK: - Dock Selection
    @Published var dockSelection: [String: String] = [:]  // selectionKey → app paths, comma-joined

    // MARK: - Form Input State
    @Published var guidanceFormInputs: [String: GuidanceFormInputState] = [:]

    // MARK: - Log Monitor State
    @Published var logMonitorStatuses: [String: String] = [:]
    /// Text a script sent with an item's status (`item:<id>:<status>:<text>`). Wins over the log
    /// channel in every state; set and cleared only by `item:`, and a status without text clears it.
    @Published var itemStatusText: [String: String] = [:]
    /// When a completed item was seen to disappear; the `wasInstalled` history `AppInspector.signal`
    /// needs to tell a removal from a cleared download. Cleared when the item completes again.
    @Published var removedItems: [String: Date] = [:]
    /// Ids whose path or cache file the path check has itself seen. It undoes a state only on that
    /// evidence, so a script-reported status stands until a real change. Not published.
    var pathCheckSawInstalled: Set<String> = []
    var pathCheckSawCaching: Set<String> = []
    var logMonitorCancellable: AnyCancellable?

    // MARK: - User Values
    @Published var userValues: [String: String] = [:]

    // MARK: - Step Model
    // Normalized reads over the view-local completion machines, registered by P5/P6; nil means the
    // shared status sets answer. Plain closures: registering must not trigger a render pass.
    var stepStatusProvider: ((String) -> StepStatus?)?
    var stepSnapshotProvider: (() -> [(id: String, stepType: String)])?
    /// Runtime overlay over `config.introSteps`; nil until the first step_add/step_remove.
    @Published var runtimeSteps: [InspectConfig.IntroStep]?

    @Published var configurationSource: ConfigurationSource = .testData
    var configPath: String?
    var lastCommandFileSize: Int = 0
    var lastProcessedLineCount: Int = 0
    /// False until monitoring starts and adopts the command file's existing content instead of
    /// replaying it (`seedCommandFileCursor`, CommandFileReplayGuard).
    var commandFileCursorSeeded: Bool = false
    var commandFileMonitor: DispatchSourceFileSystemObject?
    var updatePoll: Poll?
    var sideMessagePoll: Poll?
    var debouncedUpdater = DebouncedUpdater()
    let fileSystemCache = FileSystemCache()

    // Baselines for "changed" plist checks; nil value means the key was absent.
    var plistBaselines: [String: String?] = [:]
    var plistBaselinesInitialized: Set<String> = []

    let fsEventsMonitor = FileMonitor()
    var lastLogTime = Date()
    
    // MARK: - Services
    let configurationService = Config()

    /// The live cadence run, shared through `CadenceContext` so guidance blocks can resolve
    /// `{cadenceCount}` / `{cadenceDuration}` / `{cadenceTimeouts}`, and so the recap outlives
    /// the cadence step. `@Observable`, so bodies that read it track it directly. Lazy because the
    /// service is main-actor-isolated and `InspectState.init` is not.
    @MainActor lazy var cadenceMonitor = CadenceMonitorService()
    
    func initialize() {
        writeLog("InspectState.initialize() - Starting initialization", logLevel: .info)
        
        loadConfiguration()
        startMonitoring()
        
        writeLog("InspectState: Memory-safe initialization complete", logLevel: .info)
    }
    
    // MARK: - Watch (`"watch": true`)

    /// Polls the config file's modification date twice a second. A date, not a descriptor:
    /// editors save by rename, which a descriptor watch loses.
    private func startConfigWatch(path: String) {
        guard configWatchTimer == nil else { return }
        watchedModification = modificationDate(of: path)
        writeLog("InspectState: watching \(path) for edits", logLevel: .info)
        // Scheduled on the main run loop, so it fires on the main actor.
        configWatchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = self.modificationDate(of: path)
                guard now != nil, now != self.watchedModification else { return }
                self.watchedModification = now
                self.reloadWatchedConfiguration(path: path)
            }
        }
    }

    private func modificationDate(of path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    /// Loads one save through the launch loader. On success it replaces the config; on failure the
    /// last good config stays and `reloadIssue` carries the first lint error.
    private func reloadWatchedConfiguration(path: String) {
        switch configurationService.loadConfiguration(fromFile: path) {
        case .success(let result):
            applyReloaded(result.config)
            reloadIssue = nil
            writeLog("InspectState: reloaded \(path)", logLevel: .info)
        case .failure(let error):
            let data = FileManager.default.contents(atPath: path) ?? Data()
            let first = InspectLint.lint(data: data).first { $0.severity == .error }
            reloadIssue = first.map { ($0.path.isEmpty ? "" : "\($0.path): ") + $0.message } ?? "\(error)"
            writeLog("InspectState: \(path) did not reload — \(reloadIssue ?? "")", logLevel: .info)
        }
    }

    /// Applies a reloaded config to the running window: look, rows, steps and the log monitor's
    /// items. Steps and rows a script added at run time are dropped; the source re-adds them.
    func applyReloaded(_ newConfig: InspectConfig) {
        runtimeSteps = nil
        addedItemIDs = []
        config = newConfig
        uiConfiguration = configurationService.extractUIConfiguration(from: newConfig)
        backgroundConfiguration = configurationService.extractBackgroundConfiguration(from: newConfig)
        // An enabled Continue stays enabled: what enabled it will not fire again.
        let wasEnabled = !buttonConfiguration.button1Disabled
        buttonConfiguration = configurationService.extractButtonConfiguration(from: newConfig)
        if wasEnabled { buttonConfiguration.button1Disabled = false }
        DialogUpdatableContent.shared.inspectForcedAppearance = newConfig.appearance
        InspectAppearance.apply(newConfig.appearance)
        adoptSessionSettings(from: newConfig)
        items = newConfig.items.sorted { $0.guiIndex < $1.guiIndex }
        steps = newConfig.steps ?? []
        if uiConfiguration.sideMessages.count > 1, let interval = newConfig.sideInterval {
            startSideMessageRotation(interval: TimeInterval(interval))
        }
        validateAllItems()
        fsEventsMonitor.stopMonitoring()
        setupOptimizedFileMonitoring()
        setupOptimizedPeriodicUpdates()
        if newConfig.logMonitor != nil || newConfig.logMonitors != nil {
            LogMonitorService.shared.setItems(items)
            LogMonitorService.shared.configure(with: newConfig)
        }
    }

    /// Session settings taken from the config at launch and on every reload.
    private func adoptSessionSettings(from config: InspectConfig) {
        DateDisplayService.shared.configure(style: config.dateStyle)
        // Event mirror file: explicit eventFile, else readinessFile with .ready → .events; neither, no mirror.
        DialogNotifications.configureEventFile(
            config.eventFile ?? config.readinessFile.map { (($0 as NSString).deletingPathExtension) + ".events" }
        )
        plistSources = config.plistSources
        colorThresholds = config.colorThresholds ?? InspectConfig.ColorThresholds.default
        writeLog("InspectState: color thresholds \(config.colorThresholds == nil ? "default" : "from the config")", logLevel: .info)
    }

    // MARK: - The profile's look, live

    /// Checks the look's configuration profile (`Config.managedConfigDomain`) every 2 s; when it
    /// is installed, changed or removed, the config reloads and the open window takes the new look.
    private func startProfileWatch(from look: Data?) {
        guard profileWatch == nil else { return }
        // Copied now: the watch runs on its own queue.
        let path = appvars.inspectConfigPath, data = appvars.inspectConfigData
        let watch = ProfileLookWatch(from: look, flow: watchedFlow, load: {
            let loader = Config()
            return !path.isEmpty ? loader.loadConfiguration(fromFile: path) : data.map { loader.loadConfiguration(fromData: $0) }
        }, apply: { [weak self] config in self?.applyReloaded(config) })
        watch.start()
        profileWatch = watch
    }

    private func loadConfiguration() {
        // The profile's look before the load, so a profile landing during the load reloads once.
        let raw = appvars.inspectConfigPath.isEmpty ? appvars.inspectConfigData
            : FileManager.default.contents(atPath: appvars.inspectConfigPath)
        watchedFlow = raw.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }.flatMap(Config.flowKey(of:))
        let lookBeforeLoad = Config.profileLook(flow: watchedFlow)
        let result: Result<ConfigurationResult, ConfigurationError>
        if !appvars.inspectConfigPath.isEmpty {
            // The file loader also sets iconBasePath and resolves brandPalette tokens.
            result = configurationService.loadConfiguration(fromFile: appvars.inspectConfigPath)
        } else if let data = appvars.inspectConfigData {
            result = configurationService.loadConfiguration(fromData: data)
        } else {
            result = configurationService.loadConfiguration(fromFile: appvars.inspectConfigPath)
        }
        
        switch result {
        case .success(let configResult):
            for warning in configResult.warnings {
                writeLog("InspectState: Configuration warning - \(warning)", logLevel: .info)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let loadedConfig = configResult.config

                self.config = loadedConfig
                installTriggerLinks(config: loadedConfig)
                if loadedConfig.watch == true, !appvars.inspectConfigPath.isEmpty {
                    self.startConfigWatch(path: appvars.inspectConfigPath)
                }
                self.startProfileWatch(from: lookBeforeLoad)

                DialogUpdatableContent.shared.inspectForcedAppearance = loadedConfig.appearance

                // UI configuration before items: setting items ends the loading view.
                writeLog("InspectState: About to extract configurations", logLevel: .debug)
                writeLog("InspectState: loadedConfig.banner = \(loadedConfig.banner ?? "nil")", logLevel: .debug)
                writeLog("InspectState: loadedConfig.listIndicatorStyle = \(loadedConfig.listIndicatorStyle ?? "nil")", logLevel: .debug)
                writeLog("InspectState: loadedConfig.stepStyle = \(loadedConfig.stepStyle ?? "nil")", logLevel: .debug)
                self.uiConfiguration = self.configurationService.extractUIConfiguration(from: loadedConfig)
                writeLog("InspectState: After extraction - uiConfiguration.bannerImage = \(self.uiConfiguration.bannerImage ?? "nil")", logLevel: .debug)
                writeLog("InspectState: After extraction - uiConfiguration.iconBasePath = \(self.uiConfiguration.iconBasePath ?? "nil")", logLevel: .debug)
                writeLog("InspectState: After extraction - uiConfiguration.listIndicatorStyle = \(self.uiConfiguration.listIndicatorStyle)", logLevel: .debug)
                writeLog("InspectState: After extraction - uiConfiguration.stepStyle = \(self.uiConfiguration.stepStyle)", logLevel: .debug)
                self.backgroundConfiguration = self.configurationService.extractBackgroundConfiguration(from: loadedConfig)
                self.buttonConfiguration = self.configurationService.extractButtonConfiguration(from: loadedConfig)

                self.adoptSessionSettings(from: loadedConfig)

                // enableOnTimer and autoEnableButton both only ever enable; whichever fires first wins.
                if let enableDelay = loadedConfig.enableOnTimer, enableDelay > 0,
                   self.buttonConfiguration.button1Disabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + enableDelay) { [weak self] in
                        guard let self, self.buttonConfiguration.button1Disabled else { return }
                        self.buttonConfiguration.button1Disabled = false
                        writeLog("InspectState: enableOnTimer (\(enableDelay)s) elapsed - enabling button1", logLevel: .info)
                    }
                }

                // Setting items ends the loading view.
                self.items = loadedConfig.items.sorted { $0.guiIndex < $1.guiIndex }
                // Steps keep authored order, except preset 6 `items[]`, already in `guiIndex` order
                // (InspectConfig.orderedByGuiIndex).
                self.steps = loadedConfig.steps ?? []
                
                if self.uiConfiguration.sideMessages.count > 1, let interval = loadedConfig.sideInterval {
                    self.startSideMessageRotation(interval: TimeInterval(interval))
                }
                
                writeLog("loadedConfig.preset = \(loadedConfig.preset)", logLevel: .debug)
                writeLog("Setting preset to: \(self.uiConfiguration.preset)", logLevel: .debug)
                
                writeLog("InspectState: Loaded \(loadedConfig.items.count) items from config", logLevel: .info)
                writeLog("InspectState: Title: \(self.uiConfiguration.windowTitle)", logLevel: .debug)
                writeLog("InspectState: Using preset: \(self.uiConfiguration.preset)", logLevel: .info)
                if !self.uiConfiguration.sideMessages.isEmpty {
                    writeLog("InspectState: Side messages: \(self.uiConfiguration.sideMessages.count)", logLevel: .debug)
                }
                
                self.configurationSource = configResult.source
                switch configResult.source {
                case .file(let path):
                    writeLog("InspectState: Configuration loaded from file: \(path)", logLevel: .info)
                    self.configPath = path
                case .testData:
                    writeLog("InspectState: Using fallback test data configuration", logLevel: .info)
                case .fallback:
                    writeLog("InspectState: Using fallback configuration", logLevel: .info)
                }
                
                self.loadingState = .loaded

                // AppKit-level: .preferredColorScheme alone never flips the window.
                InspectAppearance.apply(self.config?.appearance)
                self.validateAllItems()
                self.setupOptimizedFileMonitoring()
                // Started before the config arrived; restart it at the config's `scanInterval`.
                self.setupOptimizedPeriodicUpdates()
                self.initializeProgressTracker()
                self.setupLogMonitoring(config: loadedConfig)
            }

        case .failure(let error):
            writeLog("InspectState: Configuration loading failed - \(error.localizedDescription)", logLevel: .error)
            DispatchQueue.main.async { [weak self] in
                self?.loadingState = .failed(error.localizedDescription)
            }
        }
    }
    
    
    func retryConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingState = .loading
        }
        loadConfiguration()
    }
    
    
    private func startMonitoring() {
        writeLog("InspectState.startMonitoring() - Starting all monitoring components", logLevel: .info)
        
        // FSEvents monitoring starts in loadConfiguration(): `config` is still nil here.
        seedCommandFileCursor()
        setupCommandFileMonitoring()
        setupOptimizedPeriodicUpdates()

        writeLog("InspectState: All monitoring components started successfully", logLevel: .info)
    }
    
    private func setupCommandFileMonitoring() {
        let commandFilePath = InspectConstants.commandFilePath
        
        guard FileManager.default.fileExists(atPath: commandFilePath) else {
            writeLog("InspectState: Command file doesn't exist yet: \(commandFilePath)", logLevel: .debug)
            return
        }
        
        guard commandFileMonitor == nil else {
            writeLog("InspectState: Command file monitoring already set up", logLevel: .debug)
            return
        }
        
        let fileHandle = open(commandFilePath, O_EVTONLY)
        guard fileHandle >= 0 else {
            writeLog("InspectState: Unable to open command file for monitoring: \(commandFilePath)", logLevel: .error)
            return
        }
        
        commandFileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )
        
        commandFileMonitor?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.debouncedUpdater.debounce(key: "command-file-update") { [weak self] in
                self?.updateAppStatus()
            }
        }
        
        commandFileMonitor?.setCancelHandler {
            close(fileHandle)
        }
        
        commandFileMonitor?.resume()
        writeLog("DispatchSource file monitoring active", logLevel: .info)
    }
    
    private func setupOptimizedPeriodicUpdates() {
        updatePoll?.cancel()
        let every = InspectConstants.scanInterval(config?.scanInterval)
        // Only once the config is in: the first start, before it arrives, is replaced at load.
        if config != nil {
            writeLog("InspectState: scanning item paths every \(Int(every)) s "
                     + InspectConstants.scanIntervalSource(config?.scanInterval), logLevel: .info)
        }
        let poll = Poll(every: every)
        poll.start { [weak self] in
            self?.performRobustAppCheck()
        }
        updatePoll = poll
        
        writeLog("Timer-based monitoring active", logLevel: .info)
    }
    
    private func setupOptimizedFileMonitoring() {
        let cachePaths = config?.cachePaths ?? []
        
        guard !cachePaths.isEmpty else {
            writeLog("InspectState: No cache paths configured for FSEvents monitoring", logLevel: .debug)
            return
        }
        
        fsEventsMonitor.delegate = self
        fsEventsMonitor.startMonitoring(items: items, cachePaths: cachePaths, cacheExtensions: config?.resolvedCacheExtensions)
        
        writeLog("FSEvents monitoring active", logLevel: .info)
    }

    // MARK: - Log Monitoring Setup

    private func setupLogMonitoring(config: InspectConfig) {
        guard config.logMonitor != nil || config.logMonitors != nil else {
            return
        }

        writeLog("InspectState: Setting up log monitoring", logLevel: .info)

        LogMonitorService.shared.setItems(items)
        LogMonitorService.shared.configure(with: config)

        // React only to changed statuses: the whole dictionary republishes on every change, and a
        // stale "Installing..." would demote a completed item.
        var previousStatuses: [String: String] = [:]
        logMonitorCancellable = LogMonitorService.shared.$latestStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                guard let self = self else { return }
                self.logMonitorStatuses = statuses

                for (itemId, status) in statuses {
                    guard status != previousStatuses[itemId] else { continue }
                    previousStatuses[itemId] = status

                    if status.hasPrefix("Failed") {
                        self.applyItemStatus(itemId, .failed)
                        writeLog("InspectState: Item '\(itemId)' marked as failed from log monitor", logLevel: .info)
                    } else if status == "Completed" {
                        self.applyItemStatus(itemId, .completed)
                        writeLog("InspectState: Item '\(itemId)' marked as completed from log monitor", logLevel: .info)
                    } else if self.isUpdatingStatus(status) {
                        if self.completedItems.contains(itemId) {
                            self.completedItems.remove(itemId)
                            self.downloadingItems.insert(itemId)
                            writeLog("InspectState: Item '\(itemId)' moved to updating state from log monitor: \(status)", logLevel: .info)
                        } else if !self.downloadingItems.contains(itemId) {
                            self.downloadingItems.insert(itemId)
                            writeLog("InspectState: Item '\(itemId)' marked as downloading from log monitor: \(status)", logLevel: .info)
                        }
                    }
                }
            }
    }

    /// Whether a log monitor status means an install or update is in progress.
    private func isUpdatingStatus(_ status: String) -> Bool {
        let updatingPrefixes = [
            "Installing",
            "Extracting",
            "Downloading",
            "Mounting",
            "Copying",
            "Unpacking",
            "Verifying",
            "Updating",
            "Running script"
        ]

        for prefix in updatingPrefixes where status.hasPrefix(prefix) {
            return true
        }

        if status.contains("%") {
            return true
        }

        return false
    }

    func performRobustAppCheck() {
        if Date().timeIntervalSince(lastLogTime) > 30.0 {
            writeLog("InspectState: App status monitoring active", logLevel: .debug)
            lastLogTime = Date()
        }
        
        checkCommandFileForUpdates()
        checkDirectInstallationStatus()
    }
    

    deinit {
        writeLog("InspectState.deinit() - Starting resource cleanup", logLevel: .info)

        // Deinit is non-isolated; this object is released on the main thread, and cancelling the
        // command-file source synchronously is what closes its descriptor.
        MainActor.assumeIsolated {
            updatePoll?.cancel()
            sideMessagePoll?.cancel()
            stopAllPlistMonitors()

            commandFileMonitor?.cancel()
            commandFileMonitor = nil

            fsEventsMonitor.stopMonitoring()
            fsEventsMonitor.delegate = nil

            debouncedUpdater.cancelAll()
        }

        writeLog("InspectState.deinit() - Resource cleanup completed", logLevel: .info)
    }
}
