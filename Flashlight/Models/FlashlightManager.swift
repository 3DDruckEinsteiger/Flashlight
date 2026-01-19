import SwiftUI
import Combine

// MARK: - Special Modes
enum FlashlightMode: String, CaseIterable, Codable {
    case normal = "Normal"
    case sos = "SOS"
    case candle = "Candle"
    case disco = "Disco"
    case rainbow = "Rainbow"
    case gradient = "Gradient"
}

// MARK: - Favorite Color
struct FavoriteColor: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    init(name: String, color: Color) {
        self.name = name
        let components = color.rgbComponents
        self.red = components.red
        self.green = components.green
        self.blue = components.blue
    }
}

// MARK: - Flashlight Manager
@MainActor
class FlashlightManager: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedColor: Color = .white
    @Published var brightness: Double = 1.0
    @Published var currentMode: FlashlightMode = .normal
    @Published var isFullScreen: Bool = false
    @Published var showControls: Bool = true

    // SOS settings
    @Published var isStrobeOn: Bool = true

    // Gradient settings
    @Published var gradientColor1: Color = .red
    @Published var gradientColor2: Color = .blue
    @Published var gradientProgress: Double = 0.0

    // Timer settings
    @Published var timerMinutes: Int = 0
    @Published var timerSecondsRemaining: Int = 0
    @Published var isTimerActive: Bool = false

    // Warm/Cold slider
    @Published var colorTemperature: Double = 0.5 // 0 = warm, 1 = cold

    // RGB Input
    @Published var hexInput: String = "#FFFFFF"

    // Favorites
    @Published var favorites: [FavoriteColor] = []

    // Preset colors
    let presetColors: [Color] = [
        .white, .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink
    ]

    @Published var currentPresetIndex: Int = 0

    // MARK: - Private Properties
    private var timer: Timer?
    private var modeTimer: Timer?
    private var sosIndex: Int = 0
    private var rainbowHue: Double = 0.0
    private var cancellables = Set<AnyCancellable>()

    // SOS Pattern: ... --- ... (dit dit dit, dah dah dah, dit dit dit)
    private let sosPattern: [(on: Bool, duration: Double)] = [
        // S: ...
        (true, 0.2), (false, 0.2),
        (true, 0.2), (false, 0.2),
        (true, 0.2), (false, 0.6),
        // O: ---
        (true, 0.6), (false, 0.2),
        (true, 0.6), (false, 0.2),
        (true, 0.6), (false, 0.6),
        // S: ...
        (true, 0.2), (false, 0.2),
        (true, 0.2), (false, 0.2),
        (true, 0.2), (false, 1.4),
    ]

    // MARK: - Computed Properties
    var displayColor: Color {
        switch currentMode {
        case .normal:
            return selectedColor.opacity(brightness)
        case .sos:
            return isStrobeOn ? selectedColor.opacity(brightness) : .black
        case .candle:
            return candleColor
        case .disco:
            return Color(hue: Double.random(in: 0...1), saturation: 1, brightness: brightness)
        case .rainbow:
            return Color(hue: rainbowHue, saturation: 1, brightness: brightness)
        case .gradient:
            return interpolateColor(from: gradientColor1, to: gradientColor2, progress: gradientProgress)
        }
    }

    var candleColor: Color {
        let baseHue = 0.08 // Orange-yellow
        let hueVariation = Double.random(in: -0.02...0.02)
        let brightnessVariation = Double.random(in: 0.7...1.0) * brightness
        return Color(hue: baseHue + hueVariation, saturation: 0.8, brightness: brightnessVariation)
    }

    var temperatureColor: Color {
        // Warm (2700K-ish) to Cold (6500K-ish)
        let warmColor = Color(red: 1.0, green: 0.85, blue: 0.65)
        let coldColor = Color(red: 0.85, green: 0.92, blue: 1.0)
        return interpolateColor(from: warmColor, to: coldColor, progress: colorTemperature)
    }

    // MARK: - Initialization
    init() {
        loadSettings()
        loadFavorites()
    }

    // MARK: - Mode Control
    func setMode(_ mode: FlashlightMode) {
        stopCurrentMode()
        currentMode = mode

        switch mode {
        case .normal:
            break
        case .sos:
            startSOS()
        case .candle:
            startCandle()
        case .disco:
            startDisco()
        case .rainbow:
            startRainbow()
        case .gradient:
            startGradient()
        }

        saveSettings()
    }

    func stopCurrentMode() {
        modeTimer?.invalidate()
        modeTimer = nil
        sosIndex = 0
        isStrobeOn = true
    }

    // MARK: - SOS Mode
    private func startSOS() {
        sosIndex = 0
        runSOSStep()
    }

    private func runSOSStep() {
        guard currentMode == .sos else { return }

        let step = sosPattern[sosIndex]
        isStrobeOn = step.on

        modeTimer = Timer.scheduledTimer(withTimeInterval: step.duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.sosIndex = (self.sosIndex + 1) % self.sosPattern.count
                self.runSOSStep()
            }
        }
    }

    // MARK: - Candle Mode
    private func startCandle() {
        modeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - Disco Mode
    private func startDisco() {
        modeTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - Rainbow Mode
    private func startRainbow() {
        modeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.rainbowHue += 0.005
                if self.rainbowHue > 1.0 {
                    self.rainbowHue = 0.0
                }
            }
        }
    }

    // MARK: - Gradient Mode
    private func startGradient() {
        var direction: Double = 1.0
        modeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.gradientProgress += 0.01 * direction
                if self.gradientProgress >= 1.0 {
                    direction = -1.0
                } else if self.gradientProgress <= 0.0 {
                    direction = 1.0
                }
            }
        }
    }

    // MARK: - Timer Functions
    func startTimer(minutes: Int) {
        timerMinutes = minutes
        timerSecondsRemaining = minutes * 60
        isTimerActive = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.timerSecondsRemaining > 0 {
                    self.timerSecondsRemaining -= 1
                } else {
                    self.stopTimer()
                    self.brightness = 0.0
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        timerSecondsRemaining = 0
    }

    var timerDisplay: String {
        let minutes = timerSecondsRemaining / 60
        let seconds = timerSecondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Color Navigation
    func nextColor() {
        currentPresetIndex = (currentPresetIndex + 1) % presetColors.count
        selectedColor = presetColors[currentPresetIndex]
        saveSettings()
    }

    func previousColor() {
        currentPresetIndex = (currentPresetIndex - 1 + presetColors.count) % presetColors.count
        selectedColor = presetColors[currentPresetIndex]
        saveSettings()
    }

    func increaseBrightness() {
        brightness = min(1.0, brightness + 0.1)
        saveSettings()
    }

    func decreaseBrightness() {
        brightness = max(0.1, brightness - 0.1)
        saveSettings()
    }

    // MARK: - Temperature
    func applyTemperature() {
        selectedColor = temperatureColor
    }

    // MARK: - HEX Input
    func applyHexColor() {
        if let color = Color(hex: hexInput) {
            selectedColor = color
            saveSettings()
        }
    }

    func updateHexFromColor() {
        hexInput = selectedColor.toHex
    }

    // MARK: - Favorites
    func addFavorite(name: String) {
        let favorite = FavoriteColor(name: name, color: selectedColor)
        favorites.append(favorite)
        saveFavorites()
    }

    func removeFavorite(_ favorite: FavoriteColor) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }

    func applyFavorite(_ favorite: FavoriteColor) {
        selectedColor = favorite.color
        saveSettings()
    }

    func renameFavorite(_ favorite: FavoriteColor, to newName: String) {
        if let index = favorites.firstIndex(where: { $0.id == favorite.id }) {
            favorites[index].name = newName
            saveFavorites()
        }
    }

    // MARK: - Persistence
    private func saveSettings() {
        UserDefaults.standard.set(brightness, forKey: "brightness")
        UserDefaults.standard.set(currentPresetIndex, forKey: "presetIndex")
        UserDefaults.standard.set(currentMode.rawValue, forKey: "mode")

        let components = selectedColor.rgbComponents
        UserDefaults.standard.set(components.red, forKey: "colorRed")
        UserDefaults.standard.set(components.green, forKey: "colorGreen")
        UserDefaults.standard.set(components.blue, forKey: "colorBlue")
    }

    private func loadSettings() {
        if UserDefaults.standard.object(forKey: "brightness") != nil {
            brightness = UserDefaults.standard.double(forKey: "brightness")
        }
        currentPresetIndex = UserDefaults.standard.integer(forKey: "presetIndex")

        if let modeString = UserDefaults.standard.string(forKey: "mode"),
           let mode = FlashlightMode(rawValue: modeString) {
            currentMode = mode
        }

        if UserDefaults.standard.object(forKey: "colorRed") != nil {
            let red = UserDefaults.standard.double(forKey: "colorRed")
            let green = UserDefaults.standard.double(forKey: "colorGreen")
            let blue = UserDefaults.standard.double(forKey: "colorBlue")
            selectedColor = Color(red: red, green: green, blue: blue)
        }
    }

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "favorites")
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorites"),
           let decoded = try? JSONDecoder().decode([FavoriteColor].self, from: data) {
            favorites = decoded
        }
    }

    // MARK: - Helper
    private func interpolateColor(from: Color, to: Color, progress: Double) -> Color {
        let fromComponents = from.rgbComponents
        let toComponents = to.rgbComponents

        let red = fromComponents.red + (toComponents.red - fromComponents.red) * progress
        let green = fromComponents.green + (toComponents.green - fromComponents.green) * progress
        let blue = fromComponents.blue + (toComponents.blue - fromComponents.blue) * progress

        return Color(red: red, green: green, blue: blue).opacity(brightness)
    }
}

// MARK: - Color Extensions
extension Color {
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        #if os(macOS)
        let nsColor = NSColor(self)
        if let rgbColor = nsColor.usingColorSpace(.deviceRGB) {
            return (rgbColor.redComponent, rgbColor.greenComponent, rgbColor.blueComponent)
        }
        return (1, 1, 1)
        #else
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (red, green, blue)
        #endif
    }

    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    var toHex: String {
        let components = rgbComponents
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
