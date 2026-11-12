# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build for macOS
xcodebuild -project "Screenlight.xcodeproj" -scheme "Screenlight" -destination 'platform=macOS' build

# Build for iOS Simulator
xcodebuild -project "Screenlight.xcodeproj" -scheme "Screenlight" -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' build

# Archive for App Store (macOS)
xcodebuild -project "Screenlight.xcodeproj" -scheme "Screenlight" -destination 'platform=macOS' archive

# Archive for App Store (iOS)
xcodebuild -project "Screenlight.xcodeproj" -scheme "Screenlight" -destination 'generic/platform=iOS' archive

# Clean build
xcodebuild -project "Screenlight.xcodeproj" -scheme "Screenlight" clean
```

In Xcode: `⌘B` to build, `⌘R` to run, `⌘+Shift+K` to clean build folder.

## Architecture

**Screenlight** is a SwiftUI multiplatform app (iOS/macOS) that turns the device screen into a customizable light source.

### Key Files

- `ScreenlightApp.swift` - App entry point with platform-specific window configuration
- `ContentView.swift` - Main UI with tabbed interface (Colors, Modes, Settings) and platform-specific input handling (keyboard for macOS, swipe gestures for iOS)
- `Models/ScreenlightManager.swift` - Central state manager (`@ObservableObject`) handling all business logic

### ScreenlightManager

The core of the app. Manages:
- **Color state**: Selected color, brightness, presets, favorites
- **Light modes**: Normal, SOS (morse code pattern), Candle (flickering), Disco (random colors), Rainbow (cycling hues), Gradient (interpolating between two colors)
- **Timer**: Auto-off functionality
- **Persistence**: Settings and favorites stored via `UserDefaults`

Mode animations use `Timer.scheduledTimer` with `@MainActor` dispatch for UI updates.

### Platform Differences

Handled via `#if os(macOS)` / `#if os(iOS)` conditionals:
- **macOS**: Keyboard shortcuts (arrow keys, space, escape), `NSApplication` window control, hidden title bar
- **iOS**: Swipe gestures for color/brightness, status bar hiding in fullscreen

### Color Extensions

`Color` extension in `ScreenlightManager.swift` provides:
- `rgbComponents` - Platform-specific RGB extraction (NSColor vs UIColor)
- `init?(hex:)` - Create color from hex string
- `toHex` - Convert color to hex string
