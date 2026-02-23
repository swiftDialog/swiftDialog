//
//  dialogcli
//
//  Created by Bart E Reardon on 7/7/2025.
//

import Foundation
import SystemConfiguration
import ArgumentParser
import Darwin

// Struct to hold the result of running a command (stdout, stderr, and exit status)
struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

@main
struct DialogLauncher: ParsableCommand {
    static let process = Process()
    
    // Command-line option for specifying the path to the command file
    //@Option(name: .long, help: "Path to the command file")
    //var commandfile: String?
    
    // Used to create the `/usr/local/bin/dialog` symlink
    @Flag(help: .hidden)
    var link: Bool = false


    // Collects all remaining arguments passed to the command
    @Argument(parsing: .captureForPassthrough)
    var passthroughArgs: [String] = []

    // Main function to run the logic
    func run() throws {
        // Register signal handler
        signal(SIGINT) { _ in
            fputs(" Received SIGINT, exiting...\n", stderr)
            // kill the running process
            kill(DialogLauncher.process.processIdentifier, SIGTERM)
            Darwin.exit(40)
        }
        
        // get my process id
        let myPid = getpid()
        //fputs("my pid \(myPid)\n", stderr)
        
        // Define default paths and binary locations
        let defaultCommandFile = "/var/tmp/dialog.log"
        let dialogAppPath = "/Library/Application Support/Dialog/Dialog.app"
        var dialogBinary = "\(dialogAppPath)/Contents/MacOS/Dialog"
        
        // Try to locate the actual app bundle path
        if let appBundle = findAppBundlePath() {
            //fputs("App bundle located at: \(appBundle.path)\n", stderr)
            // extract the app folder name, excluding .app
            let appName = URL(fileURLWithPath: appBundle.path).deletingPathExtension().lastPathComponent
            dialogBinary = "\(appBundle.path)/Contents/MacOS/\(appName)"
            //fputs("dialog binary should be at \(dialogBinary)\n", stderr)
        } else {
            fputs("Could not locate app bundle.\n", stderr)
        }

        // Check if the dialog binary exists
        guard FileManager.default.fileExists(atPath: dialogBinary) else {
            fputs("ERROR: Cannot find swiftDialog binary at \(dialogBinary)\n", stderr)
            throw ExitCode(255)
        }
        
        if link {
            // check if we are root
            if getuid() != 0 {
                fputs("ERROR: Must run as root to create symlink.\n", stderr)
                throw ExitCode(1)
            }
            
            // Standard bin path
            let localBinPath = "/usr/local/bin"
            
            // Ensure local bin directory exists
            if !FileManager.default.fileExists(atPath: localBinPath) {
                do {
                    try FileManager.default.createDirectory(atPath: localBinPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fputs("ERROR - could not create path at \(localBinPath)\n", stderr)
                    throw ExitCode(1)
                }
            }
            
            // create /usr/local/bin/dialog symlink
            let symlinkPath = URL(fileURLWithPath: "\(localBinPath)/dialog")
            // get path to self
            let pathToSelf = URL(fileURLWithPath: CommandLine.arguments[0])
            
            if FileManager.default.fileExists(atPath: symlinkPath.path()) {
                try? FileManager.default.removeItem(atPath: symlinkPath.path())
            }
            do {
                try FileManager.default.createSymbolicLink(at: symlinkPath, withDestinationURL: pathToSelf)
                fputs("Created symlink to \(pathToSelf.path().replacingOccurrences(of: "%20", with: " ")) at \(symlinkPath.path().replacingOccurrences(of: "%20", with: " "))\n", stdout)
            } catch {
                fputs("Could not create symlink to \(pathToSelf.path().replacingOccurrences(of: "%20", with: " "))\n", stderr)
                fputs("Verify path at \(symlinkPath.path().replacingOccurrences(of: "%20", with: " ")) exists\n", stderr)
                throw ExitCode(1)
            }
            // exit as we don't want to continue launching
            throw ExitCode(0)
        }

        // loop through looking for the command file path
        var commandFilePath = defaultCommandFile
        var index = 0
        while index < passthroughArgs.count {
            if passthroughArgs[index] == "--commandfile" {
                // Next argument should be the path
                if index + 1 < passthroughArgs.count && !passthroughArgs[index + 1].hasPrefix("--") {
                    commandFilePath = passthroughArgs[index + 1]
                    break
                }
            }
            index+=1
        }

        // Check if commandfile is a symlink and abort if found
        if FileManager.default.destinationOfSymbolicLinkSafe(atPath: commandFilePath) != nil {
            fputs("ERROR: \(commandFilePath) is a symbolic link - aborting\n", stderr)
            throw ExitCode(1)
        }

        // Ensure the command file exists and is readable
        if !FileManager.default.fileExists(atPath: commandFilePath) {
            FileManager.default.createFile(atPath: commandFilePath, contents: nil)
        } else if !FileManager.default.isReadableFile(atPath: commandFilePath) {
            fputs("WARNING: \(commandFilePath) is not readable\n", stderr)
        }

        // Get the current user info (username and UID)
        let (user, userUID) = getConsoleUserInfo()

        // Check if --loginwindow flag is present
        let hasLoginwindowFlag = passthroughArgs.contains("--loginwindow")

        // Ensure the user is valid, unless using --loginwindow at the loginwindow (console user is root)
        guard (!user.isEmpty && userUID != 0) || hasLoginwindowFlag else {
            fputs("ERROR: Unable to determine current GUI user\n", stderr)
            throw ExitCode(1)
        }
        
        // Filter out empty arguments
        let filteredArgs = passthroughArgs.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Re-order arguments
        let reorderedArgs = ["--pid", "\(myPid)", "--commandfile", "\(commandFilePath)"]+reorderArguments(filteredArgs)

        // If at loginwindow (root user with --loginwindow flag), run Dialog directly as root
        if hasLoginwindowFlag && userUID == 0 {
            let result = runCommand(binary: dialogBinary, args: reorderedArgs)
            print(result.stdout, terminator: "")
            fputs(result.stderr, stderr)
            throw ExitCode(result.status)
        }

        // Run as root if necessary, otherwise directly run the binary
        if getuid() == 0 {
            // Check if the command file is readable by the user
            if !canUserReadFile(user: user, file: commandFilePath) {
                fputs("ERROR: \(commandFilePath) is not readable by user \(user)\n", stderr)
                throw ExitCode(1)
            }

            // Run as the specified user
            let result = runAsUser(uid: userUID, user: user, binary: dialogBinary, args: reorderedArgs)
            print(result.stdout, terminator: "")
            fputs(result.stderr, stderr)
            throw ExitCode(result.status)
        } else {
            // Run directly as the current user
            let result = runCommand(binary: dialogBinary, args: reorderedArgs)
            print(result.stdout, terminator: "")
            fputs(result.stderr, stderr)
            throw ExitCode(result.status)
        }
    }

    // Helper function to get the current console user and UID
    func getConsoleUserInfo() -> (username: String, userID: UInt32) {
        var uid: uid_t = 0
        if let consoleUser = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as? String {
            return (consoleUser, uid)
        } else {
            return ("", 0)
        }
    }

    // Function to run a command as a different user using `launchctl`
    func runAsUser(uid: UInt32, user: String, binary: String, args: [String]) -> CommandResult {
        guard FileManager.default.fileExists(atPath: binary) else {
            return CommandResult(status: 255, stdout: "", stderr: "App path does not exist: \(binary)")
        }

        // Construct the arguments to run the command as the target user
        var commandArgs = ["asuser", "\(uid)", "sudo", "-H", "-u", user, binary]
        if !args.isEmpty {
            commandArgs.append(contentsOf: args)
        }

        // Run the command using `launchctl`
        return runCommand(binary: "/bin/launchctl", args: commandArgs)
    }

    // Function to execute the provided command with the specified arguments
    func runCommand(binary: String, args: [String]) -> CommandResult {
        let process = DialogLauncher.process
        process.launchPath = binary
        process.arguments = args

        // Set up pipes for stdout and stderr
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdout: String = ""
        var stderrOutput: String = ""

        // Set up a handler to stream stderr in real-time
        let stderrHandle = stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                stderrOutput += line
                fputs(line, stderr)
            }
        }

        do {
            // Start the process and capture stdout
            try process.run()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdout = String(data: stdoutData, encoding: .utf8) ?? ""

            // Wait for the process to finish and disable the stderr stream
            process.waitUntilExit()
            stderrHandle.readabilityHandler = nil

            return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderrOutput)
        } catch {
            // Handle failure to run the process
            stderrHandle.readabilityHandler = nil
            return CommandResult(status: 255, stdout: "", stderr: "Failed to run process: \(error)")
        }
    }

    // Reorder arguments such that flags without parameters go to the end
    // Needed to get around weird swiftui bug when compiled on macos 15+ and xcode 16+
    func reorderArguments(_ args: [String]) -> [String] {
        var reordered: [String] = []
        var flagsWithoutParams: [String] = []
        var index = 0

        while index < args.count {
            let arg = args[index]
            if arg.starts(with: "--") || arg.starts(with: "-") {
                if index + 1 >= args.count || args[index + 1].starts(with: "--") || args[index + 1].starts(with: "-") {
                    flagsWithoutParams.append(arg)
                    index += 1
                } else {
                    reordered.append(arg)
                    reordered.append(args[index + 1])
                    index += 2
                }
            } else {
                if !arg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && arg.count > 1 {
                    reordered.append(arg)
                    index += 1
                }
            }
        }

        reordered.append(contentsOf: flagsWithoutParams)
        return reordered
    }

    // Function to check if a user can read a specific file
    func canUserReadFile(user: String, file: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["-u", user, "test", "-r", file]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
    
    func resolvedExecutablePath() -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var size = UInt32(buffer.count)
        _ = _NSGetExecutablePath(&buffer, &size)
        let rawPath = String(cString: buffer)
        return URL(fileURLWithPath: rawPath).resolvingSymlinksInPath().path
    }
    
    func findAppBundlePath() -> URL? {
        let exeURL = URL(fileURLWithPath: resolvedExecutablePath())
        var current = exeURL

        while current.path != "/" {
            if current.pathExtension == "app" {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
    }
}

// Extension to FileManager to handle symbolic link safety checks
extension FileManager {
    func destinationOfSymbolicLinkSafe(atPath path: String) -> String? {
        var isSymlink = ObjCBool(false)
        guard fileExists(atPath: path, isDirectory: &isSymlink), isSymlink.boolValue else {
            return nil
        }
        return try? destinationOfSymbolicLink(atPath: path)
    }
}
