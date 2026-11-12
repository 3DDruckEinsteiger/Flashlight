import SwiftUI

/// Shared measurements. Spacing follows a 4/8/12/16/24 scale, touch targets are at least 44 pt.
enum Metrics {
    static let touchTarget: CGFloat = 44
    static let controlHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 14
    static let panelCornerRadius: CGFloat = 28
    static let panelMaxWidth: CGFloat = 460
}

extension ShapeStyle where Self == Color {
    /// Resting background of chips and tracks on the dark panel.
    static var chipFill: Color { Color.white.opacity(0.12) }
    /// Background of the selected chip.
    static var chipSelectedFill: Color { Color.white.opacity(0.92) }
    /// Secondary text on the panel (contrast on the panel is above 7:1).
    static var panelSecondary: Color { Color.white.opacity(0.72) }
}

// MARK: - Chip

/// A rounded button used for tabs, modes and timer choices.
/// The selected state is shown by fill *and* text colour, never by colour alone.
struct ChipStyle: ButtonStyle {
    var isSelected = false
    var minHeight: CGFloat = Metrics.touchTarget

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(isSelected ? Color.chipSelectedFill : Color.chipFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Swatch

/// A round colour button with a checkmark when selected.
struct Swatch: View {
    let color: LightColor
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(color.luminance > 0.55 ? Color.black : Color.white)
                    }
                }
                .padding(3)
                .overlay(
                    Circle().strokeBorder(Color.white, lineWidth: isSelected ? 2.5 : 0)
                )
                .frame(width: Metrics.touchTarget + 4, height: Metrics.touchTarget + 4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Slider

/// A thick slider that is easy to hit with a thumb. Works with touch, mouse,
/// VoiceOver (adjustable) and right-to-left layouts.
struct LightSlider: View {
    enum Kind {
        /// The track fills up to the current value.
        case fill
        /// A thumb moves along a fixed gradient.
        case gradient([Color])
    }

    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var kind: Kind = .fill
    /// Shown inside the filled part of the track.
    var symbol: String?
    /// Step for VoiceOver's swipe up/down.
    var step: Double = 0.1
    let label: Text
    let valueText: String

    @Environment(\.layoutDirection) private var layoutDirection

    private let height: CGFloat = Metrics.touchTarget

    private var fraction: CGFloat {
        CGFloat(((value - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped01)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                switch kind {
                case .fill:
                    Capsule().fill(Color.chipFill)
                    Capsule()
                        .fill(Color.chipSelectedFill)
                        .frame(width: height + (width - height) * fraction)
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.black)
                            .frame(width: height, height: height)
                    }
                case .gradient(let colors):
                    Capsule()
                        // .leading/.trailing follow the layout direction, so the warm end
                        // stays next to the flame icon in right-to-left languages (checked in Arabic).
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .padding(.vertical, 8)
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .frame(width: height - 8, height: height - 8)
                        // Padding (not offset) so the thumb mirrors in right-to-left layouts.
                        .padding(.leading, 4 + (width - height) * fraction)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let travel: CGFloat = max(1, width - height)
                        var position = Double((drag.location.x - height / 2) / travel).clamped01
                        if layoutDirection == .rightToLeft { position = 1 - position }
                        value = range.lowerBound + position * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            // Land on round values (10 %, 20 % …) instead of drifting.
            let current = (value / step).rounded()
            switch direction {
            case .increment: value = min(range.upperBound, (current + 1) * step)
            case .decrement: value = max(range.lowerBound, (current - 1) * step)
            @unknown default: break
            }
        }
    }
}

// MARK: - Section title

struct SectionTitle: View {
    let text: Text

    init(_ key: LocalizedStringKey) {
        text = Text(key)
    }

    var body: some View {
        text
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.panelSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Compatibility

extension View {
    /// `onChange` without deprecation warnings on current systems, still working on iOS 16.
    @ViewBuilder
    func onValueChange<Value: Equatable>(of value: Value, _ action: @escaping (Value) -> Void) -> some View {
        #if os(macOS)
        onChange(of: value) { _, newValue in action(newValue) }
        #else
        if #available(iOS 17, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
        #endif
    }
}
