import SwiftUI

/// Central app state: what the light shows, the auto-off timer and favourites.
/// Animated modes are *not* driven from here – see `ModeAnimator` – so this
/// object only publishes when the user actually changes something.
@MainActor
final class LightStore: ObservableObject {
    static let brightnessRange: ClosedRange<Double> = 0.05...1
    static let timerChoices = [1, 5, 15, 30, 60]

    @Published var isOn = true {
        didSet {
            guard isOn != oldValue else { return }
            if isOn {
                modeStart = Date()
            } else {
                cancelTimer()
            }
        }
    }

    @Published var color: LightColor = .white { didSet { scheduleSave() } }
    @Published var brightness: Double = 1 { didSet { scheduleSave() } }
    @Published var whiteTone: Double = 0.5 { didSet { scheduleSave() } }
    @Published var gradientStart = LightColor(red: 1, green: 0.2, blue: 0.3) { didSet { scheduleSave() } }
    @Published var gradientEnd = LightColor(red: 0.1, green: 0.4, blue: 1) { didSet { scheduleSave() } }
    @Published private(set) var mode: LightMode = .normal
    @Published private(set) var favorites: [FavoriteColor] = []
    @Published private(set) var timerEnd: Date?
    @Published private(set) var removedFavorite: (favorite: FavoriteColor, index: Int)?

    /// Reference point for the animated modes.
    private(set) var modeStart = Date()

    private let defaults: UserDefaults
    private var saveTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?
    private var isLoading = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        // UI tests start from a clean slate.
        if defaults.bool(forKey: "uiTestReset"), let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        #endif
        load()
        #if DEBUG
        applyScreenshotArguments()
        #endif
    }

    #if DEBUG
    /// Launch arguments used to stage App Store screenshots and UI tests.
    private func applyScreenshotArguments() {
        if defaults.bool(forKey: "uiTestLegacyFavorites") {
            // Exactly what version 1.0 wrote, to prove the update keeps it.
            let legacy = #"[{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","name":"Sky","red":0.2,"green":0.6,"blue":1}]"#
            defaults.set(Data(legacy.utf8), forKey: Key.favorites)
            loadFavorites()
        }
        if let list = defaults.string(forKey: "uiTestFavorites") {
            favorites = list.split(separator: ",").compactMap { LightColor(hex: String($0)) }
                .map { FavoriteColor(name: $0.hex, color: $0) }
        }
        let minutes = defaults.integer(forKey: "uiTestTimerMinutes")
        if minutes > 0 { startTimer(minutes: minutes) }
    }
    #endif

    // MARK: - Light

    func togglePower() {
        isOn.toggle()
        Haptics.impact()
    }

    func setMode(_ newMode: LightMode) {
        if !isOn { isOn = true }
        guard newMode != mode else { return }
        mode = newMode
        modeStart = Date()
        Haptics.selection()
        scheduleSave()
    }

    /// Picks a colour. Modes that ignore the colour fall back to steady light,
    /// because the user clearly wants to see what they just chose.
    func select(_ newColor: LightColor, haptic: Bool = true) {
        color = newColor
        if !mode.usesSelectedColor {
            mode = .normal
        }
        if !isOn { isOn = true }
        if haptic { Haptics.selection() }
    }

    func setWhiteTone(_ value: Double) {
        whiteTone = value
        select(.whiteTone(value), haptic: false)
    }

    func stepColor(by offset: Int) {
        let presets = ColorPreset.all
        let current = presets.firstIndex { $0.color.isClose(to: color) }
        let next: Int
        if let current {
            next = (current + offset + presets.count) % presets.count
        } else {
            next = offset > 0 ? 0 : presets.count - 1
        }
        select(presets[next].color)
    }

    func setBrightness(_ value: Double) {
        let clamped = min(Self.brightnessRange.upperBound, max(Self.brightnessRange.lowerBound, value))
        // A light tick every 10 % makes the swipe gesture usable without looking.
        if Int(clamped * 10 + 0.0001) != Int(brightness * 10 + 0.0001) {
            Haptics.selection()
        }
        brightness = clamped
    }

    func stepBrightness(by amount: Double) {
        setBrightness(brightness + amount)
    }

    var animatorInput: ModeAnimator.Input {
        ModeAnimator.Input(mode: mode, color: color, gradientStart: gradientStart,
                           gradientEnd: gradientEnd, brightness: brightness, reduceMotion: false)
    }

    // MARK: - Auto-off timer

    func startTimer(minutes: Int) {
        if !isOn { isOn = true }
        var secondsPerMinute = 60.0
        #if DEBUG
        // UI tests shorten the minute so that the timer can be watched running out.
        let override = defaults.double(forKey: "uiTestSecondsPerMinute")
        if override > 0 { secondsPerMinute = override }
        #endif
        let end = Date().addingTimeInterval(TimeInterval(minutes) * secondsPerMinute)
        timerEnd = end
        Haptics.selection()
        scheduleTimerTask(until: end)
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerEnd = nil
    }

    /// Called when the app returns to the foreground: suspended tasks do not
    /// fire on time, so the end date is the source of truth.
    func refreshTimer() {
        guard let end = timerEnd else { return }
        if end <= Date() {
            finishTimer()
        } else {
            scheduleTimerTask(until: end)
        }
    }

    private func scheduleTimerTask(until end: Date) {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            // Sleep in short steps and compare with the clock: a suspended app or a
            // sleeping Mac must not delay the switch-off beyond the next wake-up.
            while !Task.isCancelled, end.timeIntervalSinceNow > 0 {
                let step = min(end.timeIntervalSinceNow, 15)
                try? await Task.sleep(nanoseconds: UInt64(max(0.05, step) * 1_000_000_000))
            }
            guard !Task.isCancelled, let self, self.timerEnd == end else { return }
            self.finishTimer()
        }
    }

    private func finishTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerEnd = nil
        isOn = false
        Haptics.success()
    }

    // MARK: - Favourites

    var isCurrentColorFavorite: Bool {
        favorites.contains { $0.lightColor.isClose(to: color) }
    }

    func addCurrentColorToFavorites() {
        guard !isCurrentColorFavorite else { return }
        favorites.append(FavoriteColor(name: color.hex, color: color))
        Haptics.success()
        saveFavorites()
    }

    func removeFavorite(_ favorite: FavoriteColor) {
        guard let index = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites.remove(at: index)
        removedFavorite = (favorite, index)
        saveFavorites()
        Accessibility.announce(String(localized: "Favorite removed"))
        let seconds: UInt64 = Accessibility.isVoiceOverRunning ? 20 : 6
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.removedFavorite = nil
        }
    }

    func undoRemoveFavorite() {
        guard let removed = removedFavorite else { return }
        if !favorites.contains(where: { $0.lightColor.isClose(to: removed.favorite.lightColor) }) {
            favorites.insert(removed.favorite, at: min(removed.index, favorites.count))
        }
        removedFavorite = nil
        undoTask?.cancel()
        Haptics.selection()
        saveFavorites()
    }

    // MARK: - Persistence (keys unchanged since 1.0)

    private enum Key {
        static let brightness = "brightness"
        static let mode = "mode"
        static let red = "colorRed"
        static let green = "colorGreen"
        static let blue = "colorBlue"
        static let favorites = "favorites"
        static let whiteTone = "whiteTone"
        static let gradientStart = "gradientStart"
        static let gradientEnd = "gradientEnd"
    }

    /// Sliders change values many times per second; one write shortly after
    /// the last change is enough.
    private func scheduleSave() {
        guard !isLoading else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        defaults.set(brightness, forKey: Key.brightness)
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(color.red, forKey: Key.red)
        defaults.set(color.green, forKey: Key.green)
        defaults.set(color.blue, forKey: Key.blue)
        defaults.set(whiteTone, forKey: Key.whiteTone)
        defaults.set([gradientStart.red, gradientStart.green, gradientStart.blue], forKey: Key.gradientStart)
        defaults.set([gradientEnd.red, gradientEnd.green, gradientEnd.blue], forKey: Key.gradientEnd)
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: Key.favorites)
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        if defaults.object(forKey: Key.brightness) != nil {
            let stored = defaults.double(forKey: Key.brightness)
            // 1.0 left the brightness at 0 after its timer ran out.
            brightness = stored < Self.brightnessRange.lowerBound ? 1 : min(1, stored)
        }
        if let raw = defaults.string(forKey: Key.mode), let stored = LightMode(rawValue: raw) {
            mode = stored
        }
        if defaults.object(forKey: Key.red) != nil {
            color = LightColor(red: defaults.double(forKey: Key.red),
                               green: defaults.double(forKey: Key.green),
                               blue: defaults.double(forKey: Key.blue))
        }
        if defaults.object(forKey: Key.whiteTone) != nil {
            whiteTone = defaults.double(forKey: Key.whiteTone).clamped01
        }
        if let rgb = defaults.array(forKey: Key.gradientStart) as? [Double], rgb.count == 3 {
            gradientStart = LightColor(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        if let rgb = defaults.array(forKey: Key.gradientEnd) as? [Double], rgb.count == 3 {
            gradientEnd = LightColor(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        loadFavorites()
    }

    private func loadFavorites() {
        if let data = defaults.data(forKey: Key.favorites),
           let decoded = try? JSONDecoder().decode([FavoriteColor].self, from: data) {
            favorites = decoded
        }
    }
}
