import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class MenuViewModel: ObservableObject {
    static let shared = MenuViewModel()

    @Published var showLogs = false
    @Published var isHoveringStart = false
    @Published var isHoveringQuit = false
    @Published var isHoveringGithub = false
    
    // Command-line flag bindings
    @Published var minAmplitude: Double = 0.05
    @Published var cooldown: Double = 0.75
    @Published var speed: Double = 1.0
    
    // MARK: - Event Sound Toggles & Themes
    @Published var enableKeyboardSounds = true
    @Published var enableUSBSounds = true
    @Published var enableChargingSounds = true
    @Published var enableLidOpenSounds = true
    @Published var enableLidCloseSounds = true
    
    @Published var selectedKeyboardSound: SoundTheme = .defaultSound
    @Published var selectedUSBSound: SoundTheme = .defaultSound
    @Published var selectedChargingSound: SoundTheme = .defaultSound
    @Published var selectedLidOpenSound: SoundTheme = .defaultSound
    @Published var selectedLidCloseSound: SoundTheme = .defaultSound
    
    // MARK: - Global Audio & Special Modes (Bottom Toggles)
    @Published var globalSoundTheme: GlobalTheme = .defaultTheme
    @Published var isSexyModeEnabled = false
    @Published var isHaloModeEnabled = false
    
    // Custom URLs for audio files
    @Published var customKeyboardSoundURL: URL?
    @Published var customUSBSoundURL: URL?
    @Published var customChargingSoundURL: URL?
    @Published var customLidOpenSoundURL: URL?
    @Published var customLidCloseSoundURL: URL?
    
    // Demo GitHub Link - Change this to your actual repository URL
    let githubURL = URL(string: "https://github.com/ankitpandeynine/Spunku-mac")!

    private init() {}
    
    enum SoundTheme: String, CaseIterable, Identifiable {
        case defaultSound = "Default"
        case sexy = "Sexy Audio"
        case halo = "Halo Audio"
        case custom = "Custom..."
        var id: Self { self }
    }
    
    enum GlobalTheme: String, CaseIterable, Identifiable {
        case defaultTheme = "Standard Default"
        case immersive = "Immersive Dynamic"
        var id: Self { self }
    }

    // Identifies which Sounds/<EventType>/<Theme>/ bundle folder
    // SystemSoundEngine picks a random file from for a given event.
    enum EventType: String {
        case keyboardTap = "KeyboardTap"
        case usbAttach = "USBAttach"
        case usbDetach = "USBDetach"
        case chargingStart = "ChargingStart"
        case lidOpen = "LidOpen"
        case lidClose = "LidClose"
    }
    
    /// Constructs command-line arguments based on GUI configurations
    func buildArguments() -> [String] {
        var args: [String] = []
        args.append(contentsOf: ["--min-amplitude", String(format: "%.2f", minAmplitude)])
        
        let msCooldown = Int(cooldown * 1000)
        args.append(contentsOf: ["--cooldown", String(msCooldown)])
        
        args.append(contentsOf: ["--speed", String(format: "%.2f", speed)])
        
        if isSexyModeEnabled || selectedKeyboardSound == .sexy || selectedUSBSound == .sexy || selectedChargingSound == .sexy {
            args.append("--sexy")
        }
        if isHaloModeEnabled || selectedKeyboardSound == .halo || selectedUSBSound == .halo || selectedChargingSound == .halo {
            args.append("--halo")
        }
        
        return args
    }
    
    /// Opens system file dialog to pick a custom audio file
    func selectCustomSound(for event: String, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.audio]
        panel.message = "Select a custom audio file for \(event)"
        
        if panel.runModal() == .OK {
            completion(panel.url)
        } else {
            completion(nil)
        }
    }
}

class StatusIndicatorModel: ObservableObject {
    @Published var pulse = false
}

@available(macOS 14.0, *)
struct MainMenuView: View {
    @ObservedObject var backend = SpankProcessManager.shared
    @ObservedObject private var viewModel = MenuViewModel.shared

    var body: some View {
        VStack(spacing: 12) {
            // Header Row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SpankGUI")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("External Backend Controller")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    StatusIndicator(isRunning: backend.isRunning)
                    
                    Text(backend.isRunning ? "Running" : "Stopped")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(backend.isRunning ? .green : .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                )
            }
            
            Divider().opacity(0.4)
            
            // Parameter Sliders
            VStack(spacing: 8) {
                HStack {
                    Text("PARAMETERS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(spacing: 6) {
                    HStack {
                        Text("Min Amp:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $viewModel.minAmplitude, in: 0.01...0.50)
                            .controlSize(.mini)
                        Text(String(format: "%.2f", viewModel.minAmplitude))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Cooldown:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $viewModel.cooldown, in: 0.2...3.0)
                            .controlSize(.mini)
                        Text(String(format: "%.2fs", viewModel.cooldown))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Speed:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $viewModel.speed, in: 0.5...2.0)
                            .controlSize(.mini)
                        Text(String(format: "%.1fx", viewModel.speed))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .frame(width: 45, alignment: .trailing)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(8)
                .disabled(backend.isRunning)
            }
            
            Divider().opacity(0.4)
            
            // MARK: - Event Sounds Section (Keyboard, USB, Charging, Lid)
            VStack(spacing: 8) {
                HStack {
                    Text("EVENT SOUNDS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    // Keyboard Soundboard Option
                    HStack {
                        Toggle("Keyboard", isOn: $viewModel.enableKeyboardSounds)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        
                        Spacer()

                        // Opens the per-key soundboard grid (individual key
                        // -> individual sound file), separate from the
                        // themed tap sound above.
                        Button(action: {
                            KeyboardWindowController.shared.showWindow()
                        }) {
                            Image(systemName: "square.grid.3x3")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .help("Configure individual key sounds")
                        
                        Picker("", selection: $viewModel.selectedKeyboardSound) {
                            ForEach(MenuViewModel.SoundTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 110)
                        .onChange(of: viewModel.selectedKeyboardSound) { _, newValue in
                            if newValue == .custom {
                                viewModel.selectCustomSound(for: "Keyboard") { url in
                                    if let url = url {
                                        viewModel.customKeyboardSoundURL = url
                                    } else {
                                        viewModel.selectedKeyboardSound = .defaultSound
                                    }
                                }
                            }
                        }
                    }
                    
                    // USB Detection Option
                    HStack {
                        Toggle("USB Detection", isOn: $viewModel.enableUSBSounds)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.selectedUSBSound) {
                            ForEach(MenuViewModel.SoundTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 110)
                        .onChange(of: viewModel.selectedUSBSound) { _, newValue in
                            if newValue == .custom {
                                viewModel.selectCustomSound(for: "USB Detection") { url in
                                    if let url = url {
                                        viewModel.customUSBSoundURL = url
                                    } else {
                                        viewModel.selectedUSBSound = .defaultSound
                                    }
                                }
                            }
                        }
                    }
                    
                    // Charging State Option
                    HStack {
                        Toggle("Charging State", isOn: $viewModel.enableChargingSounds)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.selectedChargingSound) {
                            ForEach(MenuViewModel.SoundTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 110)
                        .onChange(of: viewModel.selectedChargingSound) { _, newValue in
                            if newValue == .custom {
                                viewModel.selectCustomSound(for: "Charging State") { url in
                                    if let url = url {
                                        viewModel.customChargingSoundURL = url
                                    } else {
                                        viewModel.selectedChargingSound = .defaultSound
                                    }
                                }
                            }
                        }
                    }

                    Divider().opacity(0.2)

                    // Lid Open Option
                    HStack {
                        Toggle("Lid Open", isOn: $viewModel.enableLidOpenSounds)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.selectedLidOpenSound) {
                            ForEach(MenuViewModel.SoundTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 110)
                        .onChange(of: viewModel.selectedLidOpenSound) { _, newValue in
                            if newValue == .custom {
                                viewModel.selectCustomSound(for: "Lid Open") { url in
                                    if let url = url {
                                        viewModel.customLidOpenSoundURL = url
                                    } else {
                                        viewModel.selectedLidOpenSound = .defaultSound
                                    }
                                }
                            }
                        }
                    }

                    // Lid Close Option
                    HStack {
                        Toggle("Lid Close", isOn: $viewModel.enableLidCloseSounds)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.selectedLidCloseSound) {
                            ForEach(MenuViewModel.SoundTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 110)
                        .onChange(of: viewModel.selectedLidCloseSound) { _, newValue in
                            if newValue == .custom {
                                viewModel.selectCustomSound(for: "Lid Close") { url in
                                    if let url = url {
                                        viewModel.customLidCloseSoundURL = url
                                    } else {
                                        viewModel.selectedLidCloseSound = .defaultSound
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(8)
            }
            
            Divider().opacity(0.4)
            
            // MARK: - Global Audio Options & Special Modes (Sexy & Halo Toggles)
            VStack(spacing: 8) {
                HStack {
                    Text("GLOBAL AUDIO & MODES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    // Global Default Theme Selector
                    HStack {
                        Text("Global Audio Preset")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Picker("", selection: $viewModel.globalSoundTheme) {
                            ForEach(MenuViewModel.GlobalTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.mini)
                        .frame(width: 130)
                    }
                    
                    Divider().opacity(0.2)
                    
                    // Bottom Special Mode Toggles
                    HStack(spacing: 12) {
                        Toggle("Sexy Mode", isOn: $viewModel.isSexyModeEnabled)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        
                        Spacer()
                        
                        Toggle("Halo Mode", isOn: $viewModel.isHaloModeEnabled)
                            .font(.system(size: 11, weight: .medium))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(8)
            }
            
            Divider().opacity(0.4)
            
            // Backend Action Button
            Button(action: {
                if backend.isRunning {
                    backend.stop()
                } else {
                    let args = viewModel.buildArguments()
                    backend.start(arguments: args)
                }
            }) {
                HStack {
                    Image(systemName: backend.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(backend.isRunning ? "Stop Backend Process" : "Launch Backend Process")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: backend.isRunning
                                    ? [Color.red.opacity(0.85), Color.red]
                                    : [Color.blue.opacity(0.9), Color.purple.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(
                            color: (backend.isRunning ? Color.red : Color.blue).opacity(viewModel.isHoveringStart ? 0.35 : 0.12),
                            radius: viewModel.isHoveringStart ? 6 : 3,
                            x: 0,
                            y: 1.5
                        )
                )
                .scaleEffect(viewModel.isHoveringStart ? 1.015 : 1.0)
                .animation(.easeOut(duration: 0.15), value: viewModel.isHoveringStart)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                viewModel.isHoveringStart = hovering
            }
            
            // Log Disclosure Toggler
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.showLogs.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text("Backend Process Logs")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(viewModel.showLogs ? 90 : 0))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            
            // Logs View
            if viewModel.showLogs {
                VStack(spacing: 0) {
                    HStack {
                        Text("STDOUT / STDERR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            backend.clearLogs()
                        }) {
                            Text("Clear")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(backend.logs.isEmpty ? "No logs recorded. Launch backend to see logs." : backend.logs)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .id("LogEnd")
                        }
                        .frame(height: 120)
                        .background(Color.black.opacity(0.85))
                        .onChange(of: backend.logs) {
                            withAnimation {
                                proxy.scrollTo("LogEnd", anchor: .bottom)
                            }
                        }
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().opacity(0.4)
            
            // Footer Control Bar
            HStack {
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Quit")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(viewModel.isHoveringQuit ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    viewModel.isHoveringQuit = hovering
                }
                
                Spacer()
                
                Link(destination: viewModel.githubURL) {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 9, weight: .semibold))
                        Text("GitHub")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(viewModel.isHoveringGithub ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    viewModel.isHoveringGithub = hovering
                }
                
                Spacer()
                
                Text("v1.0.0")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
        )
    }
}

struct StatusIndicator: View {
    let isRunning: Bool
    @StateObject private var model = StatusIndicatorModel()
    
    var body: some View {
        Circle()
            .fill(isRunning ? Color.green : Color.red)
            .frame(width: 8, height: 8)
            .scaleEffect(isRunning && model.pulse ? 1.25 : 1.0)
            .shadow(color: isRunning ? .green : .red, radius: isRunning && model.pulse ? 4 : 2)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    model.pulse = true
                }
            }
    }
}

struct VisualEffectView: View {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    var body: some View {
        VisualEffectRepresentable(material: material, blendingMode: blendingMode)
    }
}

struct VisualEffectRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
