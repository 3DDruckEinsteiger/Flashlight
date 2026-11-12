import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A plain sRGB colour. The app keeps its state in this value type instead of
/// `SwiftUI.Color`, so animation frames never have to round-trip through
/// UIColor/NSColor to read components.
struct LightColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red.clamped01
        self.green = green.clamped01
        self.blue = blue.clamped01
    }

    init(hue: Double, saturation: Double, brightness: Double) {
        let h = (hue - hue.rounded(.down)) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r, g, b): (Double, Double, Double)
        switch Int(h) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m)
    }

    /// Reads the sRGB components of a SwiftUI colour (used for the system colour picker).
    init(_ color: Color) {
        #if os(macOS)
        let native = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: native.redComponent, green: native.greenComponent, blue: native.blueComponent)
        #else
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: nil)
        self.init(red: r, green: g, blue: b)
        #endif
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Perceived lightness, used to pick a readable checkmark colour on swatches.
    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    var hex: String {
        String(format: "#%02X%02X%02X",
               Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    func scaled(by factor: Double) -> LightColor {
        LightColor(red: red * factor, green: green * factor, blue: blue * factor)
    }

    func isClose(to other: LightColor) -> Bool {
        abs(red - other.red) < 0.02 && abs(green - other.green) < 0.02 && abs(blue - other.blue) < 0.02
    }

    static func mix(_ a: LightColor, _ b: LightColor, _ t: Double) -> LightColor {
        let t = t.clamped01
        return LightColor(red: a.red + (b.red - a.red) * t,
                          green: a.green + (b.green - a.green) * t,
                          blue: a.blue + (b.blue - a.blue) * t)
    }

    // MARK: White tones

    static let black = LightColor(red: 0, green: 0, blue: 0)
    static let white = LightColor(red: 1, green: 1, blue: 1)
    static let warmWhite = LightColor(red: 1, green: 0.76, blue: 0.48)
    static let coolWhite = LightColor(red: 0.80, green: 0.90, blue: 1)

    /// 0 = warm (candle-like), 0.5 = neutral white, 1 = cool daylight.
    static func whiteTone(_ temperature: Double) -> LightColor {
        let t = temperature.clamped01
        return t < 0.5 ? mix(warmWhite, white, t * 2) : mix(white, coolWhite, (t - 0.5) * 2)
    }
}

/// A named preset shown as a swatch.
struct ColorPreset: Identifiable {
    let name: String
    let color: LightColor
    var id: String { color.hex }

    static let all: [ColorPreset] = [
        ColorPreset(name: String(localized: "White"), color: .white),
        ColorPreset(name: String(localized: "Warm white"), color: LightColor(red: 1, green: 0.82, blue: 0.60)),
        ColorPreset(name: String(localized: "Red"), color: LightColor(red: 1, green: 0, blue: 0)),
        ColorPreset(name: String(localized: "Orange"), color: LightColor(red: 1, green: 0.55, blue: 0)),
        ColorPreset(name: String(localized: "Yellow"), color: LightColor(red: 1, green: 0.86, blue: 0.05)),
        ColorPreset(name: String(localized: "Green"), color: LightColor(red: 0.15, green: 0.90, blue: 0.25)),
        ColorPreset(name: String(localized: "Cyan"), color: LightColor(red: 0.20, green: 0.85, blue: 1)),
        ColorPreset(name: String(localized: "Blue"), color: LightColor(red: 0.05, green: 0.40, blue: 1)),
        ColorPreset(name: String(localized: "Purple"), color: LightColor(red: 0.70, green: 0.30, blue: 1)),
        ColorPreset(name: String(localized: "Pink"), color: LightColor(red: 1, green: 0.20, blue: 0.55)),
    ]
}

/// A colour the user saved. The stored layout is unchanged from version 1.0,
/// so existing favourites keep working after the update.
struct FavoriteColor: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var red: Double
    var green: Double
    var blue: Double

    init(name: String, color: LightColor) {
        self.name = name
        self.red = color.red
        self.green = color.green
        self.blue = color.blue
    }

    var lightColor: LightColor {
        LightColor(red: red, green: green, blue: blue)
    }
}

extension Double {
    var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
}
