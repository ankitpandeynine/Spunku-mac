import Foundation
import Combine

/// SpankProcessManager manages the spank-backend executable's lifecycle.
/// The backend needs root (it talks to IOKit/AppleSPUHIDDriver for
/// accelerometer-based tap detection), so the very first launch asks for
/// administrator approval ONCE to install a narrowly-scoped passwordless
/// sudo rule for this exact binary. Every launch after that runs via
/// `sudo -n` with no further password prompts.
@MainActor
final class SpankProcessManager: ObservableObject {
    static let shared = SpankProcessManager()

    @Published private(set) var isRunning = false
    @Published private(set) var logs = ""

    private var process: Process?
    private var outputPipe: Pipe?
    private var pendingRestartArguments: [String]?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    private let maxLogCharacters = 20_000

    // A stable, rebuild-proof copy location. Referencing the binary straight
    // out of the app bundle would tie the sudoers rule to a DerivedData path
    // that changes on every clean build; this copy's path never changes no
    // matter how many times you rebuild in Xcode.
    private let stableBinaryURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".spunku/spank-backend")

    private let sudoersFilePath = "/etc/sudoers.d/spunku-backend"

    private init() {}

    /// Launches the spank-backend process. If a process is already running,
    /// it's asked to stop and relaunched with the new arguments once it
    /// actually exits.
    func start(arguments: [String]) {
        if isRunning {
            log("Restarting with new arguments...")
            pendingRestartArguments = arguments
            stop()
            return
        }
        pendingRestartArguments = nil
        prepareThenLaunch(arguments: arguments)
    }

    private func prepareThenLaunch(arguments: [String]) {
        do {
            try ensureStableBinaryInstalled()
        } catch {
            log("Error: couldn't stage the backend binary — \(error.localizedDescription)")
            return
        }

        if !passwordlessSudoIsConfigured() {
            log("First run: requesting one-time administrator approval so future launches won't ask again...")
            do {
                try grantPasswordlessSudoOnce()
                log("One-time setup complete.")
            } catch {
                log("Couldn't set up passwordless access (\(error.localizedDescription)). You may be prompted again next time.")
            }
        }

        launch(arguments: arguments)
    }

    /// Copies the bundled binary to a stable, rebuild-proof location if it's
    /// missing or out of date there.
    private func ensureStableBinaryInstalled() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif

        guard let bundledURL = bundle.url(forAuxiliaryExecutable: "spank-backend") else {
            throw NSError(domain: "SpankProcessManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "spank-backend not found in application executables"])
        }
        let bundledPath = bundledURL.path
        
        let fm = FileManager.default
        try fm.createDirectory(at: stableBinaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let bundledSize = (try? fm.attributesOfItem(atPath: bundledPath))?[.size] as? Int
        let existingSize = fm.fileExists(atPath: stableBinaryURL.path)
            ? (try? fm.attributesOfItem(atPath: stableBinaryURL.path))?[.size] as? Int
            : nil

        if existingSize == nil || existingSize != bundledSize {
            if fm.fileExists(atPath: stableBinaryURL.path) {
                try fm.removeItem(at: stableBinaryURL)
            }
            try fm.copyItem(atPath: bundledPath, toPath: stableBinaryURL.path)
        }

        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stableBinaryURL.path)
    }

    private func passwordlessSudoIsConfigured() -> Bool {
        FileManager.default.fileExists(atPath: sudoersFilePath)
    }

    /// One-time setup: asks for administrator approval to install a sudoers
    /// rule that permits passwordless `sudo` for this exact binary path only.
    /// The rule is written to a temp file and validated with `visudo -c`
    /// before ever touching the real sudoers.d directory, so a bug here can
    /// never corrupt the system's sudo configuration.
    private func grantPasswordlessSudoOnce() throws {
        let username = NSUserName()
        let sudoersLine = "\(username) ALL=(root) NOPASSWD: \(stableBinaryURL.path)"

        let setupScript = """
        #!/bin/bash
        set -e
        TMP=$(mktemp)
        echo "\(sudoersLine)" > "$TMP"
        /usr/sbin/visudo -c -f "$TMP"
        cp "$TMP" \(sudoersFilePath)
        chown root:wheel \(sudoersFilePath)
        chmod 0440 \(sudoersFilePath)
        rm -f "$TMP"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("spunku-sudo-setup-\(UUID().uuidString).sh")
        try setupScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let appleScript = "do shell script \"/bin/bash '\(scriptURL.path)'\" with administrator privileges with prompt \"spunku needs one-time admin approval so it won't ask for your password on every launch.\""

        let osascript = Process()
        osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osascript.arguments = ["-e", appleScript]

        let errorPipe = Pipe()
        osascript.standardError = errorPipe
        try osascript.run()
        osascript.waitUntilExit()

        guard osascript.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "SpankProcessManager",
                code: Int(osascript.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: (message?.isEmpty == false ? message! : "Administrator approval was cancelled.")]
            )
        }
    }

    private func launch(arguments: [String]) {
        log("Starting backend from: \(stableBinaryURL.path)")
        log("Arguments: \(arguments.isEmpty ? "None" : arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        // -n: fail immediately instead of hanging if passwordless sudo isn't
        // actually in effect for some reason (e.g. the sudoers file was
        // removed outside the app).
        process.arguments = ["-n", stableBinaryURL.path] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        self.outputPipe = pipe
        self.process = process

        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.log(output)
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                self.isRunning = false
                self.process = nil
                if proc.terminationStatus == 1 {
                    self.log("Backend exited immediately (code 1) — if this is the very first run, passwordless sudo may not have taken effect yet; try Launch again.")
                } else {
                    self.log("Backend process exited with code: \(proc.terminationStatus)")
                }

                if let pending = self.pendingRestartArguments {
                    self.pendingRestartArguments = nil
                    self.launch(arguments: pending)
                }
            }
        }

        do {
            try process.run()
            isRunning = true
            log("Backend process running with PID \(process.processIdentifier).")
        } catch {
            log("Failed to run backend process: \(error.localizedDescription)")
            self.isRunning = false
            self.process = nil
        }
    }

    /// Asks the running backend to terminate. Non-blocking — terminationHandler
    /// (set up in launch()) updates isRunning/process once the OS confirms
    /// the process has actually exited, and fires any pending restart then.
    func stop() {
        guard let process, isRunning else {
            log("Stop requested but no active process was found.")
            return
        }
        log("Terminating process \(process.processIdentifier)...")
        process.terminate()
    }

    func clearLogs() {
        logs = ""
    }

    private func log(_ message: String) {
        let clean = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return }

        let timestamp = Self.timeFormatter.string(from: Date())
        let lines = clean.components(separatedBy: .newlines)
        for line in lines {
            logs += "[\(timestamp)] \(line)\n"
        }
        if logs.count > maxLogCharacters {
            logs = String(logs.suffix(maxLogCharacters))
        }
    }
}
