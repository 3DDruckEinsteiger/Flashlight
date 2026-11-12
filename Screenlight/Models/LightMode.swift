import Foundation

/// Raw values are the identifiers stored by version 1.0 – do not rename them.
enum LightMode: String, CaseIterable, Codable, Identifiable {
    case normal = "Normal"
    case sos = "SOS"
    case candle = "Candle"
    case disco = "Disco"
    case rainbow = "Rainbow"
    case gradient = "Gradient"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return String(localized: "Steady")
        case .sos: return String(localized: "SOS")
        case .candle: return String(localized: "Candle")
        case .disco: return String(localized: "Disco")
        case .rainbow: return String(localized: "Rainbow")
        case .gradient: return String(localized: "Fade")
        }
    }

    var symbol: String {
        switch self {
        case .normal: return "flashlight.on.fill"
        case .sos: return "light.beacon.max.fill"
        case .candle: return "flame.fill"
        case .disco: return "sparkles"
        case .rainbow:
            if #available(iOS 17, macOS 14, *) { return "rainbow" }
            return "swatchpalette.fill"
        case .gradient: return "circle.lefthalf.filled"
        }
    }

    var isAnimated: Bool { self != .normal }

    /// Whether the mode shows the colour picked in the colour tab.
    var usesSelectedColor: Bool { self == .normal || self == .sos }

    /// Longest time between two redraws. Lower rates save battery; SOS needs
    /// tighter timing than the slow colour drifts.
    var frameInterval: TimeInterval {
        switch self {
        case .normal: return 1
        case .sos: return 1.0 / 30
        case .candle: return 1.0 / 20
        case .disco, .rainbow, .gradient: return 1.0 / 15
        }
    }
}

/// Pure functions that turn "seconds since the mode started" into a colour.
/// Nothing in here keeps state or timers, so the light costs nothing while
/// it is off or the app is in the background.
enum ModeAnimator {
    struct Input {
        var mode: LightMode
        var color: LightColor
        var gradientStart: LightColor
        var gradientEnd: LightColor
        var brightness: Double
        var reduceMotion: Bool
    }

    /// Morse SOS: dot = 0.2 s, dash = 0.6 s, pause after the word = 1.4 s.
    private static let sosPattern: [(on: Bool, duration: Double)] = {
        let dot: [(Bool, Double)] = [(true, 0.2), (false, 0.2)]
        let dash: [(Bool, Double)] = [(true, 0.6), (false, 0.2)]
        let s = dot + dot + [(true, 0.2), (false, 0.6)]
        let o = dash + dash + [(true, 0.6), (false, 0.6)]
        let lastS = dot + dot + [(true, 0.2), (false, 1.4)]
        return (s + o + lastS).map { (on: $0.0, duration: $0.1) }
    }()

    private static let sosLength = sosPattern.reduce(0) { $0 + $1.duration }

    static func color(_ input: Input, at time: TimeInterval) -> LightColor {
        let t = max(0, time)
        switch input.mode {
        case .normal:
            return input.color.scaled(by: input.brightness)

        case .sos:
            var position = t.truncatingRemainder(dividingBy: sosLength)
            for step in sosPattern {
                if position < step.duration {
                    return step.on ? input.color.scaled(by: input.brightness) : .black
                }
                position -= step.duration
            }
            return .black

        case .candle:
            // Layered sine waves give a soft flicker that does not look looped.
            let depth = input.reduceMotion ? 0.35 : 1.0
            let flicker = 0.10 * sin(t * 7.3) + 0.06 * sin(t * 13.7 + 1.3) + 0.04 * sin(t * 23.1 + 0.7)
            let level = 0.80 + flicker * depth
            let hue = 0.075 + 0.012 * sin(t * 3.1) * depth
            return LightColor(hue: hue, saturation: 0.85, brightness: level * input.brightness)

        case .disco:
            // At most ~1.7 colour changes per second, well below the
            // 3 flashes per second limit for photosensitive users.
            let stepLength = input.reduceMotion ? 2.4 : 0.6
            let fade = input.reduceMotion ? 1.2 : 0.12
            let step = (t / stepLength).rounded(.down)
            let within = t - step * stepLength
            let current = discoColor(step, brightness: input.brightness)
            guard within < fade, step > 0 else { return current }
            return .mix(discoColor(step - 1, brightness: input.brightness), current, within / fade)

        case .rainbow:
            let cycle = input.reduceMotion ? 40.0 : 14.0
            return LightColor(hue: t / cycle, saturation: 1, brightness: input.brightness)

        case .gradient:
            let cycle = input.reduceMotion ? 24.0 : 10.0
            let progress = 0.5 - 0.5 * cos(2 * .pi * t / cycle)
            return LightColor.mix(input.gradientStart, input.gradientEnd, progress).scaled(by: input.brightness)
        }
    }

    /// Golden-ratio steps: every colour is clearly different from the one before.
    private static func discoColor(_ step: Double, brightness: Double) -> LightColor {
        LightColor(hue: step * 0.381966, saturation: 1, brightness: brightness)
    }
}
