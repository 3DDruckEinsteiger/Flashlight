import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Short haptic confirmations. No-ops on the Mac.
@MainActor
enum Haptics {
    #if os(iOS)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    #endif

    static func selection() {
        #if os(iOS)
        selectionGenerator.selectionChanged()
        #endif
    }

    static func impact() {
        #if os(iOS)
        impactGenerator.impactOccurred()
        #endif
    }

    static func success() {
        #if os(iOS)
        notificationGenerator.notificationOccurred(.success)
        #endif
    }
}

/// Launch flags for UI tests and staged screenshots. Always false in release builds.
enum DebugLaunch {
    static func flag(_ name: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: name)
        #else
        false
        #endif
    }
}

/// Spoken feedback for VoiceOver users.
@MainActor
enum Accessibility {
    static var isVoiceOverRunning: Bool {
        #if os(iOS)
        UIAccessibility.isVoiceOverRunning
        #else
        NSWorkspace.shared.isVoiceOverEnabled
        #endif
    }

    static func announce(_ text: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: text)
        #else
        guard let window = NSApp.mainWindow else { return }
        NSAccessibility.post(element: window, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        #endif
    }
}

/// Things a flashlight needs from the device while it is shining:
/// a display that stays awake and – on iPhone and iPad – full screen brightness.
/// Everything is handed back as soon as the light is off or the app leaves the foreground.
@MainActor
enum DeviceControl {
    #if os(iOS)
    private static var brightnessBeforeLight: CGFloat?

    private static var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
    }
    #else
    private static var activity: NSObjectProtocol?
    #endif

    static func setLightActive(_ active: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = active
        guard let screen else { return }
        if active {
            if brightnessBeforeLight == nil {
                brightnessBeforeLight = screen.brightness
            }
            screen.brightness = 1
        } else if let previous = brightnessBeforeLight {
            // Only hand the old value back if the user has not changed the
            // brightness themselves in the meantime (Control Centre).
            if screen.brightness > 0.98 {
                screen.brightness = previous
            }
            brightnessBeforeLight = nil
        }
        #else
        if active, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: "Screenlight is on")
        } else if !active, let running = activity {
            ProcessInfo.processInfo.endActivity(running)
            activity = nil
        }
        #endif
    }

    #if os(macOS)
    static var isFullScreen: Bool {
        NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false
    }

    static func setFullScreen(_ fullScreen: Bool) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
        if window.styleMask.contains(.fullScreen) != fullScreen {
            window.toggleFullScreen(nil)
        }
    }
    #endif
}
