import Foundation
import AppKit
import AVFoundation
import IOKit
import IOKit.ps

@MainActor
final class SystemSoundEngine {
    static let shared = SystemSoundEngine()

    // MARK: - Audio Engine
    private let audioEngine = AVAudioEngine()
    private struct Voice {
        let player: AVAudioPlayerNode
        let pitch: AVAudioUnitTimePitch
    }
    
    private var voices: [Voice] = []
    private var nextVoiceIndex = 0
    private let voiceCount = 6
    private var bufferCache: [URL: AVAudioPCMBuffer] = [:]

    // Caches which bundled mp3s match a given "<Event>_<Theme>" filename
    // prefix, so the hot path (every keystroke, for Keyboard Tap) doesn't
    // re-scan the whole bundle on every single event. Populated lazily.
    private var prefixMatchCache: [String: [URL]] = [:]

    // MARK: - Observers / Monitors
    private var dncObservers: [NSObjectProtocol] = []
    private var wsObservers: [NSObjectProtocol] = []
    
    private var globalMouseMonitor: Any?
    private var globalKeyboardMonitor: Any?
    private var isAtTopEdge = false
    private var isEngineConfigured = false
    
    private var isPluggedIn: Bool = false
    private var isLidClosed: Bool = false
    private var lidMonitorTask: Task<Void, Never>?

    private init() {
        configureAudioGraph()
        setupSystemObservers()
        setupMouseMonitor()
        setupKeyboardMonitor()
        setupPowerMonitor()
        setupLidMonitor()
    }

    deinit {
        for token in dncObservers { DistributedNotificationCenter.default().removeObserver(token) }
        for token in wsObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyboardMonitor { NSEvent.removeMonitor(monitor) }
        lidMonitorTask?.cancel()
        
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(center, Unmanaged.passUnretained(self).toOpaque(), nil, nil)
        
        audioEngine.stop()
    }

    // MARK: - Configuration
    private func configureAudioGraph() {
        guard !isEngineConfigured else { return }

        let mixer = audioEngine.mainMixerNode
        for _ in 0..<voiceCount {
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            audioEngine.attach(player)
            audioEngine.attach(pitch)
            audioEngine.connect(player, to: pitch, format: nil)
            audioEngine.connect(pitch, to: mixer, format: nil)
            voices.append(Voice(player: player, pitch: pitch))
        }

        do {
            try audioEngine.start()
            isEngineConfigured = true
        } catch {
            NSLog("SystemSoundEngine: Failed to start AVAudioEngine: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API
    func playSound(from fileURLString: String, volume: Float = 1.0, rate: Float = 1.0, pitch: Float = 0.0) {
        Task { [weak self] in
            guard let self else { return }
            await self._playSound(from: fileURLString, volume: volume, rate: rate, pitch: pitch)
        }
    }

    /// Plays a random bundled mp3 whose filename starts with
    /// "<eventType>_<theme>" — e.g. "KeyboardTap_Sexy_1.mp3" — no subfolders
    /// needed, just drop files straight into the normal Resources group.
    /// For `.custom`, plays the single provided customURL instead.
    func playEventSound(theme: MenuViewModel.SoundTheme, eventType: MenuViewModel.EventType, customURL: URL?) {
        if theme == .custom {
            guard let customURL else { return }
            playSound(from: customURL.path)
            return
        }

        let themeTag: String
        switch theme {
        case .sexy: themeTag = "Sexy"
        case .halo: themeTag = "Halo"
        case .defaultSound, .custom: themeTag = "Default"
        }

        let prefix = "\(eventType.rawValue)_\(themeTag)"
        guard let fileURL = randomBundledFile(prefix: prefix) else {
            NSLog("SystemSoundEngine: no bundled mp3 starting with '\(prefix)' — add one to your Xcode Resources (e.g. \(prefix)_1.mp3).")
            return
        }
        playSound(from: fileURL.path)
    }

    private func randomBundledFile(prefix: String) -> URL? {
        if let cached = prefixMatchCache[prefix] {
            return cached.randomElement()
        }
        let allMP3Paths = Bundle.main.paths(forResourcesOfType: "mp3", inDirectory: nil)
        let matches = allMP3Paths
            .map { URL(fileURLWithPath: $0) }
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
        prefixMatchCache[prefix] = matches
        return matches.randomElement()
    }

    // MARK: - Internals
    private func normalizedURL(from string: String) -> URL? {
        if let url = URL(string: string), url.isFileURL { return url }
        let pathURL = URL(fileURLWithPath: string)
        return FileManager.default.fileExists(atPath: pathURL.path) ? pathURL : nil
    }

    private func loadedBuffer(for url: URL) throws -> AVAudioPCMBuffer {
        if let cached = bufferCache[url] { return cached }
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "SystemSoundEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not allocate audio buffer for \(url.lastPathComponent)"])
        }
        try file.read(into: buffer)
        bufferCache[url] = buffer
        return buffer
    }

    @MainActor
    private func _playSound(from fileURLString: String, volume: Float, rate: Float, pitch: Float) async {
        guard let url = normalizedURL(from: fileURLString) else {
            NSLog("SystemSoundEngine: Invalid file URL string: \(fileURLString)")
            return
        }
        do {
            let buffer = try loadedBuffer(for: url)
            if !audioEngine.isRunning { try audioEngine.start() }

            let voice = voices[nextVoiceIndex]
            nextVoiceIndex = (nextVoiceIndex + 1) % voices.count

            voice.player.volume = max(0.0, min(1.0, volume))
            voice.pitch.rate = max(0.25, min(4.0, rate))
            voice.pitch.pitch = max(-2400.0, min(2400.0, pitch))

            if voice.player.isPlaying { voice.player.stop() }
            voice.player.scheduleBuffer(buffer, at: nil, completionHandler: nil)
            voice.player.play()
        } catch {
            NSLog("SystemSoundEngine: Failed to play sound: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications & Observers
    private func setupSystemObservers() {
        let dnc = DistributedNotificationCenter.default()
        let lockName = Notification.Name("com.apple.screenIsLocked")
        let unlockName = Notification.Name("com.apple.screenIsUnlocked")

        let lockToken = dnc.addObserver(forName: lockName, object: nil, queue: .main) { [weak self] _ in
            self?.handleScreenLock()
        }
        let unlockToken = dnc.addObserver(forName: unlockName, object: nil, queue: .main) { [weak self] _ in
            self?.handleScreenUnlock()
        }
        dncObservers.append(contentsOf: [lockToken, unlockToken])

        let nc = NSWorkspace.shared.notificationCenter
        let mountToken = nc.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleVolumeMounted(note)
        }
        let unmountToken = nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleVolumeUnmounted(note)
        }
        wsObservers.append(contentsOf: [mountToken, unmountToken])
    }
    
    // MARK: - Keyboard Soundboard Monitor
    private func setupKeyboardMonitor() {
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            Task { @MainActor in
                self?.handleKeyboardKeypress()
            }
        }
    }
    
    private func handleKeyboardKeypress() {
        let settings = MenuViewModel.shared
        guard settings.enableKeyboardSounds else { return }
        playEventSound(
            theme: settings.selectedKeyboardSound,
            eventType: .keyboardTap,
            customURL: settings.customKeyboardSoundURL
        )
    }

    // MARK: - Power Monitor Setup
    private func setupPowerMonitor() {
        // Seed the real current power state up front so the first
        // unrelated power-info notification doesn't look like a false
        // "just plugged in" transition.
        isPluggedIn = queryIsPluggedIn()

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let notificationName = "com.apple.system.powersources.source" as CFString
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        CFNotificationCenterAddObserver(center, observer, { (_, observer, _, _, _) in
            guard let observerInfo = observer else { return }
            let mySelf = Unmanaged<SystemSoundEngine>.fromOpaque(observerInfo).takeUnretainedValue()
            
            Task { @MainActor in
                mySelf.handlePowerSourceChanged()
            }
        }, notificationName, nil, .deliverImmediately)
    }
    
    private func queryIsPluggedIn() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let state = info["Power Source State"] as? String, state == "AC Power" {
                return true
            }
        }
        return false
    }
    
    private func handlePowerSourceChanged() {
        let currentlyPluggedIn = queryIsPluggedIn()
        
        if currentlyPluggedIn != isPluggedIn {
            isPluggedIn = currentlyPluggedIn
            if isPluggedIn {
                let settings = MenuViewModel.shared
                guard settings.enableChargingSounds else { return }
                playEventSound(
                    theme: settings.selectedChargingSound,
                    eventType: .chargingStart,
                    customURL: settings.customChargingSoundURL
                )
            }
        }
    }

    // MARK: - Lid Monitor (open/close via IOKit clamshell state)
    private func setupLidMonitor() {
        isLidClosed = queryIsLidClosed()
        lidMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                checkLidState()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func queryIsLidClosed() -> Bool {
        var isClosed = false
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        if service != 0 {
            if let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
                isClosed = value
            }
            IOObjectRelease(service)
        }
        return isClosed
    }

    private func checkLidState() {
        let currentlyClosed = queryIsLidClosed()
        guard currentlyClosed != isLidClosed else { return }
        isLidClosed = currentlyClosed

        let settings = MenuViewModel.shared
        if currentlyClosed {
            guard settings.enableLidCloseSounds else { return }
            playEventSound(
                theme: settings.selectedLidCloseSound,
                eventType: .lidClose,
                customURL: settings.customLidCloseSoundURL
            )
        } else {
            guard settings.enableLidOpenSounds else { return }
            playEventSound(
                theme: settings.selectedLidOpenSound,
                eventType: .lidOpen,
                customURL: settings.customLidOpenSoundURL
            )
        }
    }

    private func handleScreenLock() {
        if let path = Bundle.main.path(forResource: "LockSound", ofType: "mp3") {
            playSound(from: path, volume: 0.9, rate: 1.0, pitch: -200)
        }
    }

    private func handleScreenUnlock() {
        if let path = Bundle.main.path(forResource: "UnlockSound", ofType: "mp3") {
            playSound(from: path, volume: 1.0, rate: 1.05, pitch: 100)
        }
    }

    private func handleVolumeMounted(_ notification: Notification) {
        let settings = MenuViewModel.shared
        guard settings.enableUSBSounds else { return }
        playEventSound(
            theme: settings.selectedUSBSound,
            eventType: .usbAttach,
            customURL: settings.customUSBSoundURL
        )
    }

    private func handleVolumeUnmounted(_ notification: Notification) {
        let settings = MenuViewModel.shared
        guard settings.enableUSBSounds else { return }
        playEventSound(
            theme: settings.selectedUSBSound,
            eventType: .usbDetach,
            customURL: settings.customUSBSoundURL
        )
    }

    // MARK: - Mouse Monitor (Notch area)
    private func setupMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkCursorAtTopBoundary()
        }
    }

    private func checkCursorAtTopBoundary() {
        guard let screen = NSScreen.main else { return }
        let mouse = NSEvent.mouseLocation
        let top = screen.frame.maxY
        let atTop = abs(mouse.y - top) <= 2.0

        if atTop && !isAtTopEdge {
            isAtTopEdge = true
            cursorHitTopBoundary()
        } else if !atTop {
            isAtTopEdge = false
        }
    }

    private func cursorHitTopBoundary() {
        if let path = Bundle.main.path(forResource: "NotchPing", ofType: "mp3") {
            playSound(from: path, volume: 0.3, rate: 1.0, pitch: 200)
        }
    }
}
