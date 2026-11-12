import SwiftUI

/// The light itself: a full-screen colour. Animated modes redraw from a
/// `TimelineView` that pauses while the light is off or the app is inactive,
/// so nothing runs in the background and steady light costs no CPU at all.
struct LightSurface: View {
    @ObservedObject var store: LightStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !store.isOn {
                Color.black
            } else if store.mode.isAnimated {
                TimelineView(.animation(minimumInterval: store.mode.frameInterval,
                                        paused: isPaused)) { context in
                    color(at: context.date).color
                }
            } else {
                color(at: store.modeStart).color
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: store.isOn)
    }

    /// On the Mac the window keeps shining while another app is in front
    /// (a light for a video call must not freeze); on iOS it pauses with the app.
    private var isPaused: Bool {
        #if os(macOS)
        scenePhase == .background
        #else
        scenePhase != .active
        #endif
    }

    private func color(at date: Date) -> LightColor {
        var input = store.animatorInput
        input.reduceMotion = reduceMotion
        return ModeAnimator.color(input, at: date.timeIntervalSince(store.modeStart))
    }
}
