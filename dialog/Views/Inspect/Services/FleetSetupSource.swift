//
//  FleetSetupSource.swift
//  dialog
//
//  The `fleet` log-monitor preset. Reads orbit's `setup_experience_progress.json` (atomic snapshot; source of
//  truth for rows and final states) and `software_install_events.jsonl` (append-only install events, rotated
//  to .1 past 5 MB, adding progress to the running row), and sends `item:`/`progress:` lines through
//  `DialogNotifications.dispatchLocally`. Row ids: sw-<title_id> · bootstrap · profile-<slug> · script.
//  Icons come from the device route with the token in /opt/orbit/identifier; the token never reaches a view.
//  Config (`path` required; `eventsPath` and `serverURL` optional):
//    "logMonitor": { "preset": "fleet", "path": "<orbit>/setup_experience_progress.json",
//                    "eventsPath": "<orbit>/software_install_events.jsonl", "serverURL": "https://fleet.example.com" }
//

import AppKit
import Foundation

// MARK: - The mapping (pure)

enum FleetSetup {
    static let eventsFileName = "software_install_events.jsonl"   // the simulator's and tests' name, not a lookup

    struct Row: Equatable {
        enum Kind: Equatable { case bootstrap, profile, software, script }
        let id: String
        let name: String
        /// Names an installer filename or a config item can match: name and display_name.
        let names: [String]
        let kind: Kind
        let status: String
        let error: String?
        /// Software only: the title id, and whether the snapshot lists an icon for it.
        var titleID: Int?
        var hasIcon = false
        /// The row's own line when its state word is not enough ("70 of 74 verified").
        var note: String?
    }

    /// What a row should say: an inspect status word, its line, and a percent when there is one.
    struct Shown: Equatable {
        let status: StepStatus
        let text: String
        let percent: Int?
    }

    /// The icon for a row Fleet has no software title for: macOS's own bundle for that kind of work, so
    /// the row reads as part of the set instead of a placeholder. nil for software (Fleet serves those).
    static func systemIcon(for kind: Row.Kind) -> String? {
        switch kind {
        case .bootstrap: return "/System/Library/CoreServices/Installer.app"
        case .profile:   return "/System/Applications/System Settings.app"
        case .script:    return "/System/Applications/Utilities/Script Editor.app"
        case .software:  return nil
        }
    }

    static func slug(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }.filter(\.isASCII)
    }

    /// Every row in orbit's order: bootstrap, profiles, software, script.
    static func rows(_ snapshot: [String: Any], profilesRow: Bool = true) -> [Row] {
        var out: [Row] = []
        if let bp = snapshot["bootstrap_package"] as? [String: Any] {
            out.append(Row(id: "bootstrap", name: bp["name"] as? String ?? "Bootstrap package", names: [],
                           kind: .bootstrap, status: bp["status"] as? String ?? "pending", error: bp["error"] as? String))
        }
        let profiles = snapshot["configuration_profiles"] as? [[String: Any]] ?? []
        for p in profiles {
            let name = p["name"] as? String ?? "Profile"
            out.append(Row(id: "profile-\(slug(name))", name: name, names: [name], kind: .profile,
                           status: p["status"] as? String ?? "pending", error: p["error"] as? String))
        }
        // One row for all profiles; a config can list a profile by name when it matters on its own.
        if profilesRow, !profiles.isEmpty {
            let states = profiles.map { ($0["status"] as? String ?? "pending").lowercased() }
            let verified = states.filter { $0 == "verified" }.count
            let status = states.contains("failed") ? "failed"
                : verified == states.count ? "verified"
                : states.contains(where: { $0 == "verifying" || $0 == "verified" }) ? "verifying" : "pending"
            out.append(Row(id: "profiles", name: "Configuration profiles", names: ["Configuration profiles"],
                           kind: .profile, status: status,
                           error: states.contains("failed") ? "\(states.filter { $0 == "failed" }.count) of \(states.count) failed" : nil,
                           note: "\(verified) of \(states.count) verified"))
        }
        for s in snapshot["software"] as? [[String: Any]] ?? [] {
            guard let tid = s["software_title_id"] as? Int else { continue }
            let name = s["name"] as? String ?? ""
            let display = (s["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            out.append(Row(id: "sw-\(tid)", name: display ?? name, names: [name] + (display.map { [$0] } ?? []),
                           kind: .software, status: s["status"] as? String ?? "pending", error: s["error"] as? String,
                           titleID: tid, hasIcon: (s["icon_url"] as? String).map { !$0.isEmpty } ?? false))
        }
        if let sc = snapshot["script"] as? [String: Any] {
            out.append(Row(id: "script", name: sc["name"] as? String ?? "Script", names: [], kind: .script,
                           status: sc["status"] as? String ?? "pending", error: sc["error"] as? String))
        }
        return out
    }

    /// Maps orbit's per-kind status words to inspect's lifecycle state.
    static func shown(_ row: Row) -> Shown {
        let st = row.status.lowercased()
        switch row.kind {
        case .profile:
            switch st {
            case "verified": return Shown(status: .completed, text: row.note ?? "Verified", percent: 100)
            case "verifying": return Shown(status: .active, text: row.note ?? "Verifying", percent: nil)
            case "failed": return Shown(status: .failed, text: row.error ?? "Failed", percent: nil)
            default: return Shown(status: .pending, text: "Waiting", percent: nil)
            }
        case .bootstrap:
            switch st {
            case "installed": return Shown(status: .completed, text: "Installed", percent: 100)
            case "failed": return Shown(status: .failed, text: row.error ?? "Failed", percent: nil)
            default: return Shown(status: .pending, text: "Waiting", percent: nil)
            }
        case .software, .script:
            switch st {
            case "success": return Shown(status: .completed, text: row.kind == .software ? "Installed" : "Done", percent: 100)
            case "failure": return Shown(status: .failed, text: row.error ?? "Failed", percent: nil)
            case "running": return Shown(status: .active, text: row.kind == .software ? "Installing" : "Running", percent: nil)
            default: return Shown(status: .pending, text: "Waiting", percent: nil)
            }
        }
    }

    /// An event's line for the row it belongs to.
    static func shown(event: [String: Any], row: Row) -> Shown {
        let pct = event["percent"] as? Int
        switch event["event"] as? String {
        case "download_started": return Shown(status: .active, text: "Downloading", percent: 0)
        case "download_progress": return Shown(status: .active, text: "Downloading · \(pct ?? 0)%", percent: pct)
        case "downloaded": return Shown(status: .active, text: "Downloaded", percent: 100)
        // Once the installer runs the download is complete: show the installing spinner.
        case "install_started": return Shown(status: .active, text: "Installing", percent: 100)
        case "install_finished":
            let code = event["exit_code"] as? Int ?? 0
            return code == 0 ? Shown(status: .completed, text: "Installed", percent: 100)
                : Shown(status: .failed, text: "\(row.error ?? "Installation failed") (exit \(code))", percent: nil)
        default: return Shown(status: .active, text: "Installing", percent: nil)
        }
    }

    /// The row an installer filename belongs to, matching its stem against title names (letters and digits
    /// only), e.g. "exampleapp.pkg" → Example App.
    static func match(filename: String, in rows: [Row]) -> Row? {
        let stem = slug(((filename as NSString).deletingPathExtension).components(separatedBy: "-").first ?? "")
        guard !stem.isEmpty else { return nil }
        // Closest name wins: exact, then longest ("Widgets-3.0.3.pkg" is Widgets, not Widget); ties go to the first
        // row.
        let hits = rows.filter { $0.kind == .software }.compactMap { row -> (Row, Int)? in
            let fit = row.names.map(slug).filter { !$0.isEmpty && (stem.contains($0) || $0.contains(stem)) }
                .map { $0 == stem ? Int.max : $0.count }.max()
            return fit.map { (row, $0) }
        }
        return hits.max { $0.1 < $1.1 }?.0
    }

    /// Joins install events to rows. Events carry an install_id, not a title; Setup Experience installs one
    /// item at a time, so an install belongs to the snapshot's running software row, or to the row its
    /// installer filename names. The snapshot can lag the events, so a row already bound is never bound
    /// to a second install; those events are held until `release` finds their row.
    struct Join {
        private(set) var rowByInstall: [String: String] = [:]
        private var held: [String: [[String: Any]]] = [:]
        private var heldOrder: [String] = []

        /// The row an install belongs to: named by its installer, else (while running) the snapshot's running
        /// software row. A finished install binds by name only.
        private func bindable(_ rows: [Row], filename: String?, finished: Bool) -> Row? {
            if let filename, let row = match(filename: filename, in: rows) { return row }
            guard !finished else { return nil }
            let bound = Set(rowByInstall.values)
            let running = rows.filter { $0.kind == .software && $0.status.lowercased() == "running" && !bound.contains($0.id) }
            return running.count == 1 ? running[0] : nil
        }

        mutating func feed(_ event: [String: Any], rows: [Row]) -> [(String, [String: Any])] {
            guard let iid = event["install_id"] as? String else { return [] }
            if rowByInstall[iid] == nil {
                let finished = event["event"] as? String == "install_finished"
                    || (held[iid] ?? []).contains { $0["event"] as? String == "install_finished" }
                let filename = event["filename"] as? String
                    ?? (held[iid] ?? []).lazy.compactMap { $0["filename"] as? String }.first
                guard let row = bindable(rows, filename: filename, finished: finished) else {
                    if held[iid] == nil { heldOrder.append(iid) }
                    held[iid, default: []].append(event)
                    return []
                }
                rowByInstall[iid] = row.id
            }
            let id = rowByInstall[iid]!
            heldOrder.removeAll { $0 == iid }
            return (held.removeValue(forKey: iid) ?? []).map { (id, $0) } + [(id, event)]
        }

        /// Each install no row has taken, oldest first: its installer name and when it began.
        func unclaimed() -> [(filename: String, began: Date?)] {
            heldOrder.compactMap { iid in
                guard let events = held[iid], let name = events.lazy.compactMap({ $0["filename"] as? String }).first
                else { return nil }
                return (name, events.first.flatMap { FleetSetup.time($0["time"]) })
            }
        }

        /// Held installs whose row the snapshot now names, oldest first, with their events in order.
        mutating func release(rows: [Row]) -> [(String, [String: Any])] {
            var out: [(String, [String: Any])] = []
            for iid in heldOrder {
                let events = held[iid] ?? []
                let filename = events.lazy.compactMap { $0["filename"] as? String }.first
                let finished = events.contains { $0["event"] as? String == "install_finished" }
                guard let row = bindable(rows, filename: filename, finished: finished) else { continue }
                rowByInstall[iid] = row.id
                out += events.map { (row.id, $0) }
                held[iid] = nil
            }
            heldOrder.removeAll { held[$0] == nil }
            return out
        }
    }

    /// What each row shows now: the snapshot's word, plus event progress on its running row. The snapshot's
    /// final word wins unless the row's events are newer (`fresh`), e.g. a reinstall after Setup Experience.
    static func compose(rows: [Row], live: [String: Shown], fresh: Set<String> = []) -> [String: Shown] {
        var out: [String: Shown] = [:]
        for row in rows {
            let base = shown(row)
            if let l = live[row.id], fresh.contains(row.id) || (base.status == .active && l.status == .active) {
                out[row.id] = l
            } else {
                out[row.id] = base
            }
        }
        return out
    }

    /// The device route for a title's icon; needs no API token.
    static func iconURL(server: String, token: String, titleID: Int) -> URL? {
        let base = server.hasSuffix("/") ? String(server.dropLast()) : server
        return URL(string: "\(base)/api/latest/fleet/device/\(token)/software/titles/\(titleID)/icon")
    }

    /// The server this Mac reports to: the fleetd profile (FleetURL only; the profile also holds the enroll
    /// secret), else orbit's launch daemon.
    static func serverURL(_ configured: String? = nil) -> String? {
        if let configured, !configured.isEmpty { return configured }
        if let profile = NSDictionary(contentsOfFile: "/Library/Managed Preferences/com.fleetdm.fleetd.config.plist"),
           let url = profile["FleetURL"] as? String, !url.isEmpty { return url }
        if let daemon = NSDictionary(contentsOfFile: "/Library/LaunchDaemons/com.fleetdm.orbit.plist"),
           let env = daemon["EnvironmentVariables"] as? [String: Any],
           let url = env["ORBIT_FLEET_URL"] as? String, !url.isEmpty { return url }
        return nil
    }

    /// orbit's device token, read fresh each time because orbit rotates it.
    static func deviceToken() -> String? {
        (try? String(contentsOfFile: "/opt/orbit/identifier", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// A row title from an installer filename: the name before its version, e.g. "Example-4.52.178-macOS.dmg"
    /// → Example. Lowercase names stay lowercase.
    static func title(fromFilename filename: String) -> String {
        let stem = (filename as NSString).deletingPathExtension
        let cut = stem.range(of: #"[-_. ]v?\d"#, options: .regularExpression).map { String(stem[..<$0.lowerBound]) }
        return ((cut?.isEmpty == false ? cut : stem) ?? stem).replacingOccurrences(of: ",", with: " ")
    }

    /// Parses an RFC 3339 time to the second; orbit writes up to nine fractional digits, which the formatter rejects.
    static func time(_ value: Any?) -> Date? {
        guard let s = value as? String, s.count >= 19 else { return nil }
        return ISO8601DateFormatter().date(from: String(s.prefix(19)) + "Z")
    }

    /// Whether a snapshot is a live run or history, decided once without trusting a possibly wrong clock:
    ///   1. `finished_at` present: history.
    ///   2. `updated_at` within 10 minutes of now: live.
    ///   3. Otherwise watch it: changed within 90 s of uptime means live, unchanged means history; nil until then.
    struct SnapshotJudge {
        enum Verdict { case live, history }
        private(set) var verdict: Verdict?
        private var watching: (stamp: String, since: TimeInterval)?

        mutating func judge(_ snapshot: [String: Any], now: Date, uptime: TimeInterval) -> Verdict? {
            if let verdict { return verdict }
            if snapshot["finished_at"] != nil {
                verdict = .history
            } else if snapshot["updated_at"] == nil {
                verdict = .live  // no stamp to judge: treat as live
            } else if let at = time(snapshot["updated_at"]), abs(at.timeIntervalSince(now)) <= 10 * 60 {
                verdict = .live
            } else {
                let stamp = snapshot["updated_at"] as? String ?? ""
                if let seen = watching {
                    if seen.stamp != stamp { verdict = .live } else if uptime - seen.since >= 90 { verdict = .history }
                } else {
                    watching = (stamp, uptime)
                }
            }
            return verdict
        }
    }

    /// Installs that are history for a window opened at `openedAt`: finished over a minute earlier, or silent
    /// for over 30 minutes (abandoned). Installers report nothing while running, hence the long margin.
    static func pastInstalls(_ events: [[String: Any]], openedAt: Date) -> Set<String> {
        var last: [String: Date] = [:], finished: Set<String> = []
        for e in events {
            guard let iid = e["install_id"] as? String, let at = time(e["time"]) else { continue }
            last[iid] = max(last[iid] ?? at, at)
            if e["event"] as? String == "install_finished" { finished.insert(iid) }
        }
        return Set(last.filter { iid, at in
            at < openedAt.addingTimeInterval(finished.contains(iid) ? -60 : -30 * 60)
        }.keys)
    }

    static func commands(id: String, _ s: Shown) -> [String] {
        ["item:\(id):\(s.status.rawValue):\(s.text)"] + (s.percent.map { ["progress:\(id):\($0)"] } ?? [])
    }
}

// MARK: - The source

/// Polls the snapshot, reads the event stream incrementally and sends changes to the active command router.
/// One per `fleet` monitor; `LogMonitorService` owns its lifetime.
final class FleetSetupSource: @unchecked Sendable {
    private let snapshotPath: String
    private let eventsPath: String?
    private let serverURL: String?
    private let interval: TimeInterval
    private let refresh: TimeInterval
    /// Config item id for a row the config names by display name.
    private var aliases: [String: String] = [:]
    /// The single "Configuration profiles" row; off with `showProfilesRow: false`.
    private var profilesRow: Bool
    private let queue = DispatchQueue(label: "swiftdialog.fleet-setup", qos: .utility)
    private var timer: DispatchSourceTimer?

    // Confined to `queue`.
    private var offset: UInt64 = 0
    /// Installs that ended before this window opened (`FleetSetup.pastInstalls`): never bound, shown or held.
    private var past: Set<String> = []
    /// Whether the snapshot is a run in progress or history, decided once (`FleetSetup.SnapshotJudge`).
    private var judge = FleetSetup.SnapshotJudge()
    /// The events file's identity; a new one means orbit rotated it.
    private var eventsFileID: UInt64?
    private var warnedVersion = false
    /// The last file-state message logged; logged again only when it changes.
    private var lastSeen = ""
    /// The config's app rows, for reading events without a snapshot (bootstrap, profiles and script excluded).
    private var configRows: [FleetSetup.Row] = []
    /// Rows for installs the config does not list, named from the installer; each is announced once with
    /// `listitem: add`, and again after `setItems`.
    private var addedRows: [FleetSetup.Row] = []
    private var announced: Set<String> = []
    /// The row order last sent (`listitem: order`), from the snapshot. Internal for tests.
    private(set) var sentOrder: [String] = []
    /// Only installs started after this (less a minute) get their own row; the events file keeps months of history.
    private let startedAt: Date
    /// Titles whose icon has been requested, once per source.
    private var iconsRequested: Set<Int> = []
    /// Rows given a system icon, once per source.
    private var systemIconsSent: Set<String> = []
    private static let iconCache: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appendingPathComponent("swiftDialog/FleetIcons", isDirectory: true)
    private var join = FleetSetup.Join()
    /// Each row's state from its events. Internal for tests.
    private(set) var live: [String: FleetSetup.Shown] = [:]
    /// When each row's latest event happened, compared with the snapshot's updated_at.
    private var liveAt: [String: Date] = [:]
    /// What each row was last sent. Internal for tests.
    private(set) var sent: [String: FleetSetup.Shown] = [:]
    private var lastFull = Date.distantPast

    /// Delivers lines to the active command router on the main queue; injectable for tests.
    private let emit: @MainActor @Sendable (String) -> Void

    init(snapshotPath: String, eventsPath: String? = nil, serverURL: String? = nil,
         profilesRow: Bool = true,
         items: [any MonitoredItem], interval: TimeInterval = 1.0, refresh: TimeInterval = 3.0, startedAt: Date = Date(),
         emit: @escaping @MainActor @Sendable (String) -> Void = { DialogNotifications.dispatchLocally($0) }) {
        self.snapshotPath = snapshotPath
        self.emit = emit
        self.startedAt = startedAt
        self.eventsPath = eventsPath
        self.serverURL = serverURL
        self.profilesRow = profilesRow
        self.interval = interval
        self.refresh = refresh
        adopt(items)
    }

    /// Sets whether the profiles row shows (`showProfilesRow`).
    func setProfilesRow(_ on: Bool) { queue.async { [self] in profilesRow = on } }

    func setItems(_ items: [any MonitoredItem]) {
        queue.async { [self] in
            adopt(items)
            sent = [:]  // new rows have been sent nothing yet
            announced = []  // nor seen the added rows
            sentOrder = []  // nor their order
        }
    }

    private func adopt(_ items: [any MonitoredItem]) {
        addedRows.removeAll { row in items.contains { $0.id == row.id } }  // the config lists it now
        // A name with no Latin letters or digits slugs to ""; skip it so it does not match everything.
        aliases = Dictionary(items.compactMap { item in
            let key = FleetSetup.slug(item.displayName)
            return key.isEmpty ? nil : (key, item.id)
        }, uniquingKeysWith: { first, _ in first })
        configRows = items.filter { !["bootstrap", "script"].contains($0.id) && !$0.id.hasPrefix("profile-") }
            .map { FleetSetup.Row(id: $0.id, name: $0.displayName, names: [$0.displayName], kind: .software,
                                  status: "pending", error: nil) }
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
        writeLog("FleetSetupSource: snapshot \(snapshotPath) · events \(eventsPath ?? "none") ", logLevel: .info)
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// One read of both files. Runs on `queue` from the timer; tests call it directly.
    func tick() {
        let events = eventsPath.map { "events \(Self.fileState($0))" } ?? "no events file configured"
        guard let data = FileManager.default.contents(atPath: snapshotPath) else {
            note("snapshot \(Self.fileState(snapshotPath)) · \(events)"
                 + (eventsPath == nil ? "" : " · events only: rows from the config, joined by installer name"))
            return eventsOnly()
        }
        guard let snapshot = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return note("snapshot is not JSON · \(events)")
        }
        if let v = snapshot["version"] as? Int, v > 1, !warnedVersion {
            warnedVersion = true
            writeLog("FleetSetupSource: snapshot version \(v) is newer than 1 — reading what this build knows",
                     logLevel: .info)
        }
        // A finished snapshot is history: read events only, and new installs get their own rows.
        let wasJudged = judge.verdict != nil
        let verdict = judge.judge(snapshot, now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
        if !wasJudged, let verdict {
            writeLog("FleetSetupSource: the snapshot is \(verdict == .live ? "a run in progress" : "history — events only")",
                     logLevel: .info)
        }
        guard verdict == .live else {
            note("snapshot \(verdict == nil ? "being judged (live or history)" : "is history") · \(events) · events only")
            return eventsOnly()
        }
        let rows = FleetSetup.rows(snapshot, profilesRow: profilesRow)
        // Log rows that no config item matches by id or name.
        let configIDs = Set(aliases.values)
        // Profiles are carried by the profiles row; other snapshot rows without a config row get their own,
        // so an empty install list fills from the server.
        let unlisted = rows.filter { row in
            !(row.kind == .profile && row.id != "profiles") && !ids(for: row.id, rows: rows).contains(where: configIDs.contains)
        }
        note("snapshot \(rows.count) rows, \(snapshot["done"] ?? "?") of \(snapshot["total"] ?? "?") done · \(events)"
             + (unlisted.isEmpty ? "" : " · added from Fleet: \(unlisted.map(\.name).joined(separator: ", "))"))
        requestIcons(rows)
        readEvents(rows: rows)
        for (rowId, e) in join.release(rows: rows) {
            guard let row = rows.first(where: { $0.id == rowId }) else { continue }
            apply(e, to: row)
        }
        let force = Date().timeIntervalSince(lastFull) >= refresh
        if force { lastFull = Date() }
        let snapshotAt = FleetSetup.time(snapshot["updated_at"])
        let fresh = Set(liveAt.filter { at in snapshotAt.map { at.value > $0 } ?? false }.keys)
        var lines: [String] = []
        for row in unlisted where !announced.contains(row.id) {
            announced.insert(row.id)
            let title = row.kind == .script ? "Finishing setup" : row.kind == .bootstrap ? "Bootstrap package" : row.name
            lines.append("listitem: add, id: \(row.id), title: \(title.replacingOccurrences(of: ",", with: " "))")
        }
        // Remove rows this reader added that the snapshot no longer lists; config rows stay.
        let listed = Set(unlisted.map(\.id))
        for id in announced.subtracting(listed).sorted() {
            announced.remove(id)
            sent[id] = nil
            lines.append("listitem: delete, id: \(id)")
        }
        let known = configIDs.union(announced)
        // Follow the snapshot's order, so renamed or added titles move without a config change.
        var order: [String] = []
        for row in rows { for id in ids(for: row.id, rows: rows) where known.contains(id) && !order.contains(id) { order.append(id) } }
        if order.count > 1, order != sentOrder {
            sentOrder = order
            lines.append("listitem: order, ids: " + order.joined(separator: "|"))
        }
        for (rowId, shown) in FleetSetup.compose(rows: rows, live: live, fresh: fresh) where force || sent[rowId] != shown {
            sent[rowId] = shown
            for id in ids(for: rowId, rows: rows) {
                lines += FleetSetup.commands(id: id, shown)
            }
        }
        guard !lines.isEmpty else { return }
        let emit = self.emit, out = lines
        DispatchQueue.main.async { out.forEach(emit) }
    }

    /// For each row with a server icon: the cached copy first, then a fresh fetch. Only decodable images are used.
    private func requestIcons(_ rows: [FleetSetup.Row]) {
        for row in rows where row.titleID == nil && !systemIconsSent.contains(row.id) {
            guard let path = FleetSetup.systemIcon(for: row.kind), FileManager.default.fileExists(atPath: path)
            else { continue }
            systemIconsSent.insert(row.id)
            send(icon: path, ids: ids(for: row.id, rows: rows))
        }
        guard let cache = Self.iconCache else { return }
        for row in rows where row.hasIcon {
            guard let tid = row.titleID, !iconsRequested.contains(tid) else { continue }
            iconsRequested.insert(tid)
            let file = cache.appendingPathComponent("\(tid).png")
            let ids = ids(for: row.id, rows: rows)
            if FileManager.default.fileExists(atPath: file.path) { send(icon: file.path, ids: ids) }
            guard let server = FleetSetup.serverURL(serverURL), let token = FleetSetup.deviceToken(),
                  let url = FleetSetup.iconURL(server: server, token: token, titleID: tid) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
                guard let self, let data, (response as? HTTPURLResponse)?.statusCode == 200,
                      NSImage(data: data) != nil else { return }
                try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
                guard (try? data.write(to: file, options: .atomic)) != nil else { return }
                self.queue.async { self.send(icon: file.path, ids: ids) }
            }.resume()
        }
    }

    private func send(icon path: String, ids: [String]) {
        let lines = ids.map { "itemicon:\($0):\(path)" }
        let emit = self.emit
        DispatchQueue.main.async { lines.forEach(emit) }
    }

    /// The row's id plus any config item id that names it by display name.
    private func ids(for rowId: String, rows: [FleetSetup.Row]) -> [String] {
        guard let row = rows.first(where: { $0.id == rowId }) else { return [rowId] }
        let alias = ([row.name] + row.names).lazy.compactMap { self.aliases[FleetSetup.slug($0)] }.first
        return alias.map { $0 == rowId ? [rowId] : [rowId, $0] } ?? [rowId]
    }

    /// Without a snapshot (after Setup Experience): config rows stand in, installs join the row their installer
    /// names, and install_finished's exit code gives the outcome.
    private func eventsOnly() {
        guard eventsPath != nil else { return }
        var rows = configRows + addedRows
        readEvents(rows: rows)
        // An install the config does not list gets its own row, named from the installer.
        for (filename, began) in join.unclaimed() where !((began ?? .distantPast) < startedAt.addingTimeInterval(-60)) {   // not <= / >= on Date (see SlotPickerCopy.resolve)
            let title = FleetSetup.title(fromFilename: filename), id = "app-" + FleetSetup.slug(title)
            guard !FleetSetup.slug(title).isEmpty, !rows.contains(where: { $0.id == id }) else { continue }
            let row = FleetSetup.Row(id: id, name: title, names: [title], kind: .software, status: "pending", error: nil)
            addedRows.append(row)
            rows.append(row)
        }
        var lines: [String] = []
        for row in addedRows where !announced.contains(row.id) {
            announced.insert(row.id)
            lines.append("listitem: add, id: \(row.id), title: \(row.name), status: wait")
        }
        for (rowId, e) in join.release(rows: rows) {
            guard let row = rows.first(where: { $0.id == rowId }) else { continue }
            apply(e, to: row)
        }
        for (rowId, shown) in live where sent[rowId] != shown {
            sent[rowId] = shown
            lines += FleetSetup.commands(id: rowId, shown)
        }
        guard !lines.isEmpty else { return }
        let emit = self.emit, out = lines
        DispatchQueue.main.async { out.forEach(emit) }
    }

    private func apply(_ event: [String: Any], to row: FleetSetup.Row) {
        live[row.id] = FleetSetup.shown(event: event, row: row)
        liveAt[row.id] = FleetSetup.time(event["time"])
    }

    private func note(_ seen: String) {
        guard seen != lastSeen else { return }
        lastSeen = seen
        writeLog("FleetSetupSource: \(seen)", logLevel: .info)
    }

    /// "missing", "not readable (permissions)" (folder or file), or "readable".
    static func fileState(_ path: String) -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return fm.isReadableFile(atPath: (path as NSString).deletingLastPathComponent) ? "missing" : "not readable (folder permissions)"
        }
        return fm.isReadableFile(atPath: path) ? "readable" : "not readable (permissions)"
    }

    private static func fileID(_ path: String) -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.systemFileNumber] as? UInt64) ?? nil
    }

    private func readEvents(rows: [FleetSetup.Row]) {
        guard let eventsPath else { return }
        let id = Self.fileID(eventsPath)
        if let previous = eventsFileID, id != previous {
            // Rotated: finish the old file (.1) from the last offset, then read the new one from the start.
            let rotated = eventsPath + ".1"
            if Self.fileID(rotated) == previous { consume(path: rotated, rows: rows) }
            offset = 0
        }
        eventsFileID = id
        consume(path: eventsPath, rows: rows)
    }

    /// Every whole line from `offset`; a line still being written waits for the next tick.
    private func consume(path: String, rows: [FleetSetup.Row]) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        if size < offset { offset = 0 }  // truncated instead of rotated
        guard size > offset else { return }
        try? handle.seek(toOffset: offset)
        guard let chunk = try? handle.read(upToCount: Int(size - offset)), !chunk.isEmpty,
              let lastNewline = chunk.lastIndex(of: UInt8(ascii: "\n")) else { return }
        let complete = chunk[chunk.startIndex...lastNewline]
        offset += UInt64(complete.count)
        let events = complete.split(separator: UInt8(ascii: "\n")).compactMap {
            (try? JSONSerialization.jsonObject(with: Data($0))) as? [String: Any]
        }
        // The first read is the whole history; installs that ended before this window opened are skipped.
        past.formUnion(FleetSetup.pastInstalls(events, openedAt: startedAt))
        for event in events where !past.contains(event["install_id"] as? String ?? "") {
            for (rowId, e) in join.feed(event, rows: rows) {
                guard let row = rows.first(where: { $0.id == rowId }) else { continue }
                apply(e, to: row)
            }
        }
    }
}
