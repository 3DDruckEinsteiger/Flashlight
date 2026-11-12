import SwiftUI

/// Root view: the light fills the screen, the controls float above it.
struct ContentView: View {
    @ObservedObject var store: LightStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var panelVisible = !UserDefaults.standard.bool(forKey: "startLightOnly")
    @State private var dragAxis: Axis?
    @State private var dragStartBrightness = 1.0
    @State private var hudVisible = UserDefaults.standard.bool(forKey: "uiTestShowHUD")
    @State private var hudTask: Task<Void, Never>?
    @AppStorage("hintDismissed") private var hintDismissed = false
    #if os(macOS)
    @FocusState private var isFocused: Bool
    #endif

    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            LightSurface(store: store)
                .contentShape(Rectangle())
                .gesture(surfaceDrag)
                .onTapGesture { setPanelVisible(!panelVisible) }
                .accessibilityElement()
                .accessibilityLabel(Text("Light"))
                .accessibilityValue(store.isOn ? Text("On") : Text("Off"))
                .accessibilityHint(Text("Double tap to show or hide the controls."))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("surface")

            if hudVisible {
                brightnessHUD
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 12) {
                if panelVisible, store.isOn, !hintDismissed, !isCompactHeight {
                    hint
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if panelVisible {
                    ControlPanel(store: store) { setPanelVisible(false) }
                        .frame(maxWidth: Metrics.panelMaxWidth)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompactHeight ? .trailing : .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(systemScheme)
        .onAppear { updateDevice() }
        .onValueChange(of: store.isOn) { isOn in
            updateDevice()
            // Never leave the user with a black screen and no controls.
            if !isOn { setPanelVisible(true) }
        }
        .onValueChange(of: scenePhase) { phase in
            updateDevice()
            if phase == .active {
                store.refreshTimer()
            } else {
                store.saveNow()
            }
        }
        #if os(iOS)
        .statusBarHidden(!panelVisible)
        .persistentSystemOverlays(panelVisible ? .automatic : .hidden)
        #else
        .frame(minWidth: 420, minHeight: 640)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.leftArrow) { store.stepColor(by: -1); return .handled }
        .onKeyPress(.rightArrow) { store.stepColor(by: 1); return .handled }
        .onKeyPress(.upArrow) { adjustBrightness(by: 0.1); return .handled }
        .onKeyPress(.downArrow) { adjustBrightness(by: -0.1); return .handled }
        .onKeyPress(.space) { store.togglePower(); return .handled }
        .onKeyPress(.escape) {
            guard !panelVisible else { return .ignored }
            setPanelVisible(true)
            return .handled
        }
        #endif
    }

    /// The status bar follows the system colour scheme, so the scheme follows
    /// the light: dark clock on bright light, white clock on dark light.
    /// The control panel itself is always dark.
    private var systemScheme: ColorScheme {
        guard store.isOn, !store.mode.isAnimated else { return .dark }
        return store.color.scaled(by: store.brightness).luminance > 0.5 ? .light : .dark
    }

    // MARK: - Device

    private func updateDevice() {
        DeviceControl.setLightActive(store.isOn && scenePhase != .background)
    }

    private func setPanelVisible(_ visible: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            panelVisible = visible
        }
        #if os(macOS)
        // "Light only" on the Mac also fills the whole display.
        if !visible {
            DeviceControl.setFullScreen(true)
        } else if DeviceControl.isFullScreen {
            DeviceControl.setFullScreen(false)
        }
        isFocused = true
        #endif
    }

    // MARK: - Gestures on the light

    /// Up/down changes the brightness continuously, left/right steps through the colours.
    private var surfaceDrag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { drag in
                guard store.isOn else { return }
                if dragAxis == nil {
                    dragAxis = abs(drag.translation.width) > abs(drag.translation.height) ? .horizontal : .vertical
                    dragStartBrightness = store.brightness
                }
                if dragAxis == .vertical {
                    // A swipe across roughly 400 pt covers the whole range.
                    store.setBrightness(dragStartBrightness - drag.translation.height / 400)
                    showHUD()
                }
            }
            .onEnded { drag in
                if dragAxis == .horizontal, abs(drag.translation.width) > 40, store.isOn {
                    store.stepColor(by: drag.translation.width < 0 ? 1 : -1)
                }
                if dragAxis != nil { hintDismissed = true }
                dragAxis = nil
            }
    }

    private func adjustBrightness(by amount: Double) {
        store.stepBrightness(by: amount)
        showHUD()
    }

    private func showHUD() {
        guard !panelVisible else { return }
        hudVisible = true
        hudTask?.cancel()
        hudTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { hudVisible = false }
        }
    }

    // MARK: - Overlays

    private var brightnessHUD: some View {
        Label(store.brightness.formatted(.percent.precision(.fractionLength(0))), systemImage: "sun.max.fill")
            .font(.title2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .accessibilityHidden(true)
    }

    private var hint: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                #if os(iOS)
                Label("Swipe up or down: brightness", systemImage: "arrow.up.arrow.down")
                Label("Swipe sideways: color", systemImage: "arrow.left.arrow.right")
                Label("Tap: show or hide controls", systemImage: "hand.tap")
                #else
                Label { Text(verbatim: "↑ ↓  ") + Text("Brightness") } icon: { Image(systemName: "arrow.up.arrow.down") }
                Label { Text(verbatim: "← →  ") + Text("Color") } icon: { Image(systemName: "arrow.left.arrow.right") }
                Label("Space: light on or off", systemImage: "power")
                #endif
            }
            .font(.footnote.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                withAnimation { hintDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .frame(width: Metrics.touchTarget, height: Metrics.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close tips"))
            .accessibilityIdentifier("hint.close")
        }
        .foregroundStyle(Color.white)
        .padding(.leading, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.09).opacity(0.9))
        )
        .frame(maxWidth: Metrics.panelMaxWidth)
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#Preview {
    ContentView(store: LightStore())
}
