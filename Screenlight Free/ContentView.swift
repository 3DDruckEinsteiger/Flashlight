import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ContentView: View {
    @StateObject private var manager = ScreenlightManager()
    @State private var showSettings = false
    @State private var showFavorites = false
    @State private var newFavoriteName = ""
    @State private var showAddFavorite = false
    @State private var selectedTab = 0
    @FocusState private var isFocused: Bool

    // Base font size for better readability
    private let baseFontSize: CGFloat = 18

    var body: some View {
        ZStack {
            // Background - the actual flashlight
            manager.displayColor
                .ignoresSafeArea()
                #if os(iOS)
                .gesture(swipeGestures)
                #endif
                .onTapGesture {
                    // Nur im Vollbild kann man Controls togglen
                    if manager.isFullScreen {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            manager.showControls.toggle()
                        }
                    }
                }

            // Controls overlay - zeige Controls wenn:
            // 1. Nicht im Vollbild (immer anzeigen)
            // 2. Im Vollbild und showControls ist true
            if !manager.isFullScreen || manager.showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .statusBarHidden(manager.isFullScreen && !manager.showControls)
        #endif
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        .focusable()
        .focused($isFocused)
        .onAppear {
            // Focus setzen damit Tastatureingaben funktionieren
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onKeyPress(.leftArrow) {
            manager.previousColor()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            manager.nextColor()
            return .handled
        }
        .onKeyPress(.upArrow) {
            manager.increaseBrightness()
            return .handled
        }
        .onKeyPress(.downArrow) {
            manager.decreaseBrightness()
            return .handled
        }
        .onKeyPress(.space) {
            withAnimation {
                toggleFullScreen()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if manager.isFullScreen {
                withAnimation {
                    exitFullScreen()
                }
            }
            return .handled
        }
        #endif
    }

    #if os(macOS)
    func toggleFullScreen() {
        manager.isFullScreen.toggle()
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
        if manager.isFullScreen {
            // Im Vollbild: Controls nach 2 Sekunden ausblenden
            manager.showControls = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if manager.isFullScreen {
                    withAnimation {
                        manager.showControls = false
                    }
                }
            }
        } else {
            manager.showControls = true
        }
    }

    func exitFullScreen() {
        manager.isFullScreen = false
        manager.showControls = true
        if let window = NSApplication.shared.windows.first {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }
    #endif

    // MARK: - Swipe Gestures (iOS)
    #if os(iOS)
    var swipeGestures: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                if abs(horizontal) > abs(vertical) {
                    // Horizontal swipe
                    if horizontal > 0 {
                        manager.nextColor()
                    } else {
                        manager.previousColor()
                    }
                } else {
                    // Vertical swipe
                    if vertical < 0 {
                        manager.increaseBrightness()
                    } else {
                        manager.decreaseBrightness()
                    }
                }
            }
    }
    #endif

    // MARK: - Controls Overlay
    var controlsOverlay: some View {
        VStack(spacing: 0) {
            // Header - nur wenn nicht im Vollbild
            if !manager.isFullScreen {
                headerView
            }

            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Tab selector
                    tabSelector

                    // Tab content
                    Group {
                        switch selectedTab {
                        case 0:
                            colorsTab
                        case 1:
                            modesTab
                        case 2:
                            settingsTab
                        default:
                            colorsTab
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }

            // Bottom controls
            bottomControls
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.85))
                .ignoresSafeArea()
        )
    }

    // MARK: - Header
    var headerView: some View {
        VStack(spacing: 8) {
            Text("Screenlight Free")
                .font(.system(size: 32, weight: .bold))

            #if os(iOS)
            Text("Swipe to change color/brightness")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            #else
            Text("Use arrow keys to change color/brightness")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            #endif

            // Timer display
            if manager.isTimerActive {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: baseFontSize))
                    Text(manager.timerDisplay)
                        .font(.system(size: baseFontSize, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundColor(.orange)
                .padding(.top, 4)
            }
        }
        .padding(.top)
    }

    // MARK: - Tab Selector
    var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Colors", icon: "paintpalette", index: 0)
            tabButton(title: "Modes", icon: "wand.and.stars", index: 1)
            tabButton(title: "Settings", icon: "gearshape", index: 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
        .padding(.horizontal)
    }

    func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedTab == index ? Color.white.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colors Tab
    var colorsTab: some View {
        VStack(spacing: 24) {
            // Preset colors
            VStack(alignment: .leading, spacing: 12) {
                Text("Preset Colors")
                    .font(.system(size: baseFontSize, weight: .semibold))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(Array(manager.presetColors.enumerated()), id: \.offset) { index, color in
                        colorButton(color: color, index: index)
                    }
                }
            }

            // Custom color picker
            HStack {
                Text("Custom Color")
                    .font(.system(size: baseFontSize))
                Spacer()
                ColorPicker("", selection: $manager.selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 50, height: 50)
            }

            // HEX input
            HStack {
                Text("HEX")
                    .font(.system(size: baseFontSize))
                TextField("#FFFFFF", text: $manager.hexInput)
                    .font(.system(size: baseFontSize))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    #if os(iOS)
                    .autocapitalization(.allCharacters)
                    #endif
                Button("Apply") {
                    manager.applyHexColor()
                }
                .font(.system(size: 16))
                .buttonStyle(.bordered)
            }

            // Warm/Cold slider
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Color Temperature")
                        .font(.system(size: baseFontSize))
                    Spacer()
                    Button("Apply") {
                        manager.applyTemperature()
                    }
                    .font(.system(size: 16))
                    .buttonStyle(.bordered)
                }

                HStack {
                    Image(systemName: "flame")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    Slider(value: $manager.colorTemperature)
                    Image(systemName: "snowflake")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan)
                }
            }

            // Brightness slider
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Brightness")
                        .font(.system(size: baseFontSize))
                    Spacer()
                    Text("\(Int(manager.brightness * 100))%")
                        .font(.system(size: baseFontSize))
                        .monospacedDigit()
                }

                Slider(value: $manager.brightness, in: 0.1...1.0)
                    .tint(manager.selectedColor)
            }

            // Favorites section
            favoritesSection
        }
    }

    func colorButton(color: Color, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                manager.currentPresetIndex = index
                manager.selectedColor = color
            }
        }) {
            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(manager.currentPresetIndex == index ? Color.white : Color.clear, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.2), radius: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Favorites Section
    var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorites")
                    .font(.system(size: baseFontSize, weight: .semibold))
                Spacer()
                Button(action: { showAddFavorite = true }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
            }

            if manager.favorites.isEmpty {
                Text("No favorites yet")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(manager.favorites) { favorite in
                        favoriteButton(favorite: favorite)
                    }
                }
            }
        }
        .alert("Add Favorite", isPresented: $showAddFavorite) {
            TextField("Name", text: $newFavoriteName)
            Button("Cancel", role: .cancel) {
                newFavoriteName = ""
            }
            Button("Save") {
                if !newFavoriteName.isEmpty {
                    manager.addFavorite(name: newFavoriteName)
                    newFavoriteName = ""
                }
            }
        }
    }

    func favoriteButton(favorite: FavoriteColor) -> some View {
        Button(action: {
            manager.applyFavorite(favorite)
        }) {
            VStack(spacing: 6) {
                Circle()
                    .fill(favorite.color)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.2), radius: 2)

                Text(favorite.name)
                    .font(.system(size: 14))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                manager.removeFavorite(favorite)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Modes Tab
    var modesTab: some View {
        VStack(spacing: 20) {
            // Mode grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(ScreenlightMode.allCases, id: \.self) { mode in
                    modeButton(mode: mode)
                }
            }

            // Mode-specific settings
            if manager.currentMode == .gradient {
                gradientSettings
            }
        }
    }

    func modeButton(mode: ScreenlightMode) -> some View {
        Button(action: {
            withAnimation {
                manager.setMode(mode)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: modeIcon(for: mode))
                    .font(.system(size: 22))
                Text(mode.rawValue)
                    .font(.system(size: baseFontSize))
                Spacer()
                if manager.currentMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(manager.currentMode == mode ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
    }

    func modeIcon(for mode: ScreenlightMode) -> String {
        switch mode {
        case .normal: return "flashlight.on.fill"
        case .sos: return "sos"
        case .candle: return "flame"
        case .disco: return "party.popper"
        case .rainbow: return "rainbow"
        case .gradient: return "paintbrush"
        }
    }

    var gradientSettings: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Gradient Colors")
                    .font(.system(size: baseFontSize, weight: .semibold))
                Spacer()
            }

            HStack {
                VStack(spacing: 8) {
                    Text("Start")
                        .font(.system(size: 16))
                    ColorPicker("", selection: $manager.gradientColor1, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 50, height: 50)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 24))

                Spacer()

                VStack(spacing: 8) {
                    Text("End")
                        .font(.system(size: 16))
                    ColorPicker("", selection: $manager.gradientColor2, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 50, height: 50)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
    }

    // MARK: - Settings Tab
    var settingsTab: some View {
        VStack(spacing: 20) {
            // Timer section
            VStack(alignment: .leading, spacing: 14) {
                Text("Auto-Off Timer")
                    .font(.system(size: baseFontSize, weight: .semibold))

                HStack(spacing: 12) {
                    ForEach([5, 10, 15, 30], id: \.self) { minutes in
                        Button("\(minutes)m") {
                            manager.startTimer(minutes: minutes)
                        }
                        .font(.system(size: 16))
                        .buttonStyle(.bordered)
                    }

                    if manager.isTimerActive {
                        Button("Stop") {
                            manager.stopTimer()
                        }
                        .font(.system(size: 16))
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }

                if manager.isTimerActive {
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: baseFontSize))
                        Text("Time remaining: \(manager.timerDisplay)")
                            .font(.system(size: baseFontSize))
                            .monospacedDigit()
                    }
                    .foregroundColor(.orange)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
            )

            // Keyboard shortcuts info (Mac only)
            #if os(macOS)
            keyboardShortcutsInfo
            #endif

            // Gesture info (iOS only)
            #if os(iOS)
            gestureInfo
            #endif
        }
    }

    #if os(macOS)
    var keyboardShortcutsInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.system(size: baseFontSize, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                shortcutRow(key: "← →", action: "Change color")
                shortcutRow(key: "↑ ↓", action: "Adjust brightness")
                shortcutRow(key: "Space", action: "Start/Stop flashlight")
                shortcutRow(key: "Esc", action: "Stop flashlight")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
    }

    func shortcutRow(key: String, action: String) -> some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                )
            Text(action)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
    #endif

    #if os(iOS)
    var gestureInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gestures")
                .font(.system(size: baseFontSize, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                gestureRow(icon: "hand.draw", action: "Swipe left/right to change color")
                gestureRow(icon: "hand.draw", action: "Swipe up/down to adjust brightness")
                gestureRow(icon: "hand.tap", action: "Tap in fullscreen to show/hide controls")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
    }

    func gestureRow(icon: String, action: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 30)
            Text(action)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
    #endif

    // MARK: - Bottom Controls
    var bottomControls: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                #if os(macOS)
                toggleFullScreen()
                #else
                manager.isFullScreen.toggle()
                if manager.isFullScreen {
                    manager.showControls = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if manager.isFullScreen {
                            withAnimation {
                                manager.showControls = false
                            }
                        }
                    }
                } else {
                    manager.showControls = true
                }
                #endif
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: manager.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "flashlight.on.fill")
                    .font(.system(size: 22))
                Text(manager.isFullScreen ? "Stop Screenlight" : "Start Screenlight")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .padding()
    }
}

#Preview {
    ContentView()
}
