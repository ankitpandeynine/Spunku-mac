import SwiftUI

@main
struct SpankGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No real window — menu bar icon + popover only.
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let popover = NSPopover()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hide the Dock icon / app switcher entry — this is a menu-bar-only utility.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "bolt.horizontal.circle.fill", accessibilityDescription: "SpankGUI") {
                image.isTemplate = true // adapts to light/dark menu bar automatically
                button.image = image
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        if #available(macOS 14.0, *) {
            popover.contentViewController = NSHostingController(rootView: MainMenuView())
        } else {
            popover.contentViewController = NSHostingController(rootView: AnyView(Text("SpankGUI requires macOS 14 or newer").padding()))
        }
        popover.behavior = .transient

        // Restored: the old per-key soundboard's global key monitor, back
        // on at your request alongside SystemSoundEngine's own themed
        // "Keyboard Tap" monitor. Heads up — any key you've individually
        // mapped here will now play TWO sounds per press if the "Keyboard"
        // toggle in Event Sounds is also on: the per-key custom sound AND
        // the generic themed tap sound. Turn one of them off if you don't
        // want that layering.
        KeyboardSoundboardManager.shared.startMonitoring()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SpankProcessManager.shared.stop()
        KeyboardSoundboardManager.shared.stopMonitoring()
    }
}
