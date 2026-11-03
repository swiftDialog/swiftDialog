//
//  ButtonActions.swift
//  dialog
//
//  Engine for page buttons (--button / "button"): runs shell actions "in the blind" in their own
//  process group, keeps track of them so dismissal can be blocked and force quit can kill them,
//  and a few helpers shared by the button views.
//

import Foundation
import SwiftUI
import AppKit
import Darwin

// MARK: - Running shell actions

final class ButtonActionRunner {

    static let shared = ButtonActionRunner()

    private let lock = NSLock()
    /// pid (which is also the process group id) -> description for logging
    private var running: [pid_t: String] = [:]

    var hasRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !running.isEmpty
    }

    /// Start a shell command on a background thread. Output and exit code are logged, never printed
    /// to stdout. `completion` is called on the main queue with the exit code (-1 if it could not
    /// be started, 128+n if it was killed by signal n).
    func run(_ command: String, label: String, completion: @escaping (Int32) -> Void) {
        writeLog("Button action '\(label)': running \(command)")

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawn_file_actions_destroy(&fileActions)
            posix_spawnattr_destroy(&attributes)
        }

        // stdout and stderr share one pipe so we can log them
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            writeLog("Button action '\(label)': could not create pipe", logLevel: .error)
            DispatchQueue.main.async { completion(-1) }
            return
        }
        posix_spawn_file_actions_adddup2(&fileActions, fds[1], 1)
        posix_spawn_file_actions_adddup2(&fileActions, fds[1], 2)
        posix_spawn_file_actions_addclose(&fileActions, fds[0])
        posix_spawn_file_actions_addclose(&fileActions, fds[1])

        // Own process group (pgid == pid) so the whole tree can be signalled
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)

        var argv: [UnsafeMutablePointer<CChar>?] = ["/bin/zsh", "-c", command].map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }

        var environment: [UnsafeMutablePointer<CChar>?] = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { environment.forEach { free($0) } }

        var pid: pid_t = 0
        let result = posix_spawn(&pid, "/bin/zsh", &fileActions, &attributes, argv, environment)
        close(fds[1])
        guard result == 0 else {
            close(fds[0])
            writeLog("Button action '\(label)': could not start (\(result))", logLevel: .error)
            DispatchQueue.main.async { completion(-1) }
            return
        }

        lock.lock()
        running[pid] = label
        lock.unlock()

        let readFD = fds[0]
        DispatchQueue.global(qos: .utility).async { [self] in
            var output = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = read(readFD, &buffer, buffer.count)
                if count <= 0 { break }
                output.append(buffer, count: count)
            }
            close(readFD)

            var status: Int32 = 0
            waitpid(pid, &status, 0)
            let code: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)

            lock.lock()
            running.removeValue(forKey: pid)
            lock.unlock()

            if let text = String(data: output, encoding: .utf8), !text.isEmpty {
                writeLog("Button action '\(label)' output: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            writeLog("Button action '\(label)' exited with \(code)", logLevel: code == 0 ? .info : .error)
            DispatchQueue.main.async { completion(code) }
        }
    }

    /// Terminate every running action and its child processes.
    func killAll() {
        lock.lock()
        let groups = Array(running)
        lock.unlock()
        guard !groups.isEmpty else { return }

        for (pid, label) in groups {
            writeLog("Terminating button action '\(label)'")
            killpg(pid, SIGTERM)
        }
        usleep(300_000)
        for (pid, _) in groups {
            killpg(pid, SIGKILL)   // anything still alive after the grace period
        }
    }
}

// MARK: - Signals

private var actionSignalSources: [DispatchSourceSignal] = []

/// On SIGTERM / SIGINT / SIGHUP, kill running button actions and then die by the same signal, so
/// the exit status seen by dialogcli, MDM tooling and scripts is exactly what it is without this.
/// (SIGKILL can't be caught: actions started by a kill -9'd dialog are left running.)
func installButtonActionSignalHandlers() {
    guard actionSignalSources.isEmpty else { return }
    let queue = DispatchQueue(label: "swiftdialog.button.signals")
    for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
        signal(signalNumber, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: queue)
        source.setEventHandler {
            ButtonActionRunner.shared.killAll()
            signal(signalNumber, SIG_DFL)
            raise(signalNumber)
        }
        source.resume()
        actionSignalSources.append(source)
    }
}

// MARK: - URL action

/// Open a URL (or a file path). Returns 0 on success, 1 if it couldn't be opened.
func openButtonURL(_ target: String) -> Int32 {
    writeLog("Button action: opening \(target)")
    let url: URL?
    if let parsed = URL(string: target), parsed.scheme != nil {
        url = parsed
    } else {
        url = URL(fileURLWithPath: (target as NSString).expandingTildeInPath)
    }
    guard let url else { return 1 }
    return NSWorkspace.shared.open(url) ? 0 : 1
}

// MARK: - Symbol spec

/// Parsed SF Symbol description for page buttons, same vocabulary as --button1symbol:
/// "name,colour=blue,size=28,palette=red-blue,hierarchical". A leading "SF=" is accepted, as is the
/// JSON object form.
struct ButtonSymbolSpec {
    var name: String = ""
    var colour: Color?
    var size: CGFloat?
    var mode: SymbolRenderingMode?
    var palette: [Color] = []

    init(_ raw: String) {
        let normalized = normalizedButtonSymbol(raw)
        let parts = normalized.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard var first = parts.first else { return }
        if first.lowercased().hasPrefix("sf=") { first = String(first.dropFirst(3)) }
        name = first
        for part in parts.dropFirst() {
            let lower = part.lowercased()
            if lower.hasPrefix("size="), let value = Double(lower.dropFirst(5)) {
                size = CGFloat(value)
            } else if lower.hasPrefix("colour=") || lower.hasPrefix("color=") {
                colour = Color(argument: String(lower.split(separator: "=", maxSplits: 1).last ?? "primary"))
            } else if lower.hasPrefix("palette=") {
                mode = .palette
                palette = (lower.split(separator: "=", maxSplits: 1).last ?? "").split(separator: "-").map { Color(argument: String($0)) }
            } else if let renderingMode = lower.toSymbolRenderingMode {
                mode = renderingMode
            }
        }
    }
}

// MARK: - Colour <-> hex

extension Color {
    /// "#RRGGBB" in sRGB
    var hexString: String {
        let colour = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        return String(format: "#%02X%02X%02X",
                      Int((colour.redComponent * 255).rounded()),
                      Int((colour.greenComponent * 255).rounded()),
                      Int((colour.blueComponent * 255).rounded()))
    }
}
