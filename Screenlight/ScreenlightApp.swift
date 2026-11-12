import SwiftUI

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
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
