import Cocoa
import SwiftUI
import Combine

/// Owns the persisted key-code -> sound-file mapping and the global key
/// listener that actually plays a sound when a mapped key is pressed. Starts
/// once from AppDelegate and keeps running for the app's lifetime, independent
/// of whether the KeyboardView configuration window is open.
final class KeyboardSoundboardManager: ObservableObject {
    static let shared = KeyboardSoundboardManager()

    @Published private(set) var mappedKeys: [Int: String] = [:]
    @Published private(set) var lastPressedKey: Int? = nil

    private let defaultsKey = "SpankKeyboardMaps"
    private var globalMonitor: Any?
    private var clearHighlightWorkItem: DispatchWorkItem?

    private init() {
        load()
    }

    func setMapping(keyCode: Int, path: String) {
        mappedKeys[keyCode] = path
        save()
    }

    func clearAll() {
        mappedKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    // Property lists (what UserDefaults uses under the hood) only support
    // String dictionary keys, so key codes are stringified going in and
    // parsed back coming out.
    private func save() {
        let stringKeyed = mappedKeys.reduce(into: [String: String]()) { result, item in
            result[String(item.key)] = item.value
        }
        UserDefaults.standard.set(stringKeyed, forKey: defaultsKey)
    }

    private func load() {
        guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] else { return }
        mappedKeys = saved.reduce(into: [Int: String]()) { result, item in
            if let key = Int(item.key) {
                result[key] = item.value
            }
        }
    }

    /// Requires Input Monitoring permission (System Settings > Privacy &
    /// Security > Input Monitoring). There's no automatic system prompt for
    /// this the way there is for Camera/Microphone — the monitor just
    /// silently receives zero events until the user grants it and the app
    /// relaunches.
    func startMonitoring() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let code = Int(event.keyCode)
            DispatchQueue.main.async {
                self?.handleKeyDown(code: code)
            }
        }
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleKeyDown(code: Int) {
        guard let path = mappedKeys[code] else { return }

        // Bridges into SystemSoundEngine's @MainActor isolation from this
        // plain manager class.
        Task { @MainActor in
            SystemSoundEngine.shared.playSound(from: path)
        }

        lastPressedKey = code
        clearHighlightWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            if self?.lastPressedKey == code {
                self?.lastPressedKey = nil
            }
        }
        clearHighlightWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    deinit {
        stopMonitoring()
    }
}

/// Hosts KeyboardView in its own standalone window — the 600x400 soundboard
/// grid needs more room than the menu bar popover comfortably gives it.
final class KeyboardWindowController: NSWindowController {
    static let shared = KeyboardWindowController()

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyboard Soundboard"
        window.center()
        window.isReleasedWhenClosed = false // keep this singleton's window alive after it's closed once
        window.contentViewController = NSHostingController(rootView: KeyboardView())
        self.init(window: window)
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
