import SwiftUI

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    #if DEBUG
    /// `-uiTestSnapshot <file.png>`: draws the window content into a PNG and quits.
    /// Used for App Store screenshots of the Mac version without capturing the screen.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let path = UserDefaults.standard.string(forKey: "uiTestSnapshot") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let window = NSApp.windows.first(where: { $0.contentView != nil }) else { return NSApp.terminate(nil) }
            window.setContentSize(NSSize(width: 1440, height: 900))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
                NSApp.terminate(nil)
            }
        }
    }
    #endif
}
#endif

@main
struct ScreenlightApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @StateObject private var store = LightStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Light") {
                Button(store.isOn ? "Turn off" : "Turn on") { store.togglePower() }
                    .keyboardShortcut("l", modifiers: .command)
                Divider()
                Button("Brighter") { store.stepBrightness(by: 0.1) }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button("Dimmer") { store.stepBrightness(by: -0.1) }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                Divider()
                Button("Next color") { store.stepColor(by: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous color") { store.stepColor(by: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Divider()
                Picker("Mode", selection: Binding(get: { store.mode }, set: { store.setMode($0) })) {
                    ForEach(LightMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }
        }
        #endif
    }
}
