import SwiftUI

// MARK: - Colour

struct ColorSection: View {
    @ObservedObject var store: LightStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var customColor: Binding<Color> {
        Binding(
            get: { store.color.color },
            set: { store.select(LightColor($0), haptic: false) }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ColorPreset.all) { preset in
                    Swatch(color: preset.color,
                           name: preset.name,
                           isSelected: store.mode.usesSelectedColor && store.color.isClose(to: preset.color)) {
                        store.select(preset.color)
                    }
                }
            }

            VStack(spacing: 4) {
                SectionTitle("White tone")
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(LightColor.warmWhite.color)
                    LightSlider(
                        value: Binding(get: { store.whiteTone }, set: { store.setWhiteTone($0) }),
                        kind: .gradient([LightColor.warmWhite.color, .white, LightColor.coolWhite.color]),
                        label: Text("White tone"),
                        valueText: whiteToneDescription
                    )
                    Image(systemName: "snowflake")
                        .foregroundStyle(LightColor.coolWhite.color)
                }
                .accessibilityElement(children: .contain)
            }

            HStack(spacing: 8) {
                ColorPicker(selection: customColor, supportsOpacity: false) {
                    Label("Custom", systemImage: "eyedropper")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: Metrics.touchTarget)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                        .fill(Color.chipFill)
                )

                Button {
                    store.addCurrentColorToFavorites()
                } label: {
                    Label(store.isCurrentColorFavorite ? "Saved" : "Save color",
                          systemImage: store.isCurrentColorFavorite ? "star.fill" : "star")
                }
                .buttonStyle(ChipStyle())
                .disabled(store.isCurrentColorFavorite)
            }

            if !store.favorites.isEmpty {
                favorites
            }
        }
    }

    private var whiteToneDescription: String {
        switch store.whiteTone {
        case ..<0.35: return String(localized: "Warm")
        case 0.65...: return String(localized: "Cool")
        default: return String(localized: "Neutral")
        }
    }

    private var favorites: some View {
        VStack(spacing: 4) {
            SectionTitle("Favorites · touch and hold to remove")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.favorites) { favorite in
                        Swatch(color: favorite.lightColor,
                               name: favorite.name,
                               isSelected: store.mode.usesSelectedColor && store.color.isClose(to: favorite.lightColor)) {
                            store.select(favorite.lightColor)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                store.removeFavorite(favorite)
                            } label: {
                                Label("Remove favorite", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: Text("Remove favorite")) {
                            store.removeFavorite(favorite)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mode

struct ModeSection: View {
    @ObservedObject var store: LightStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(LightMode.allCases) { mode in
                    Button {
                        store.setMode(mode)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                                .font(.title3)
                                .frame(height: 24)
                            Text(mode.title)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(ChipStyle(isSelected: store.mode == mode, minHeight: 68))
                    .accessibilityAddTraits(store.mode == mode ? [.isSelected] : [])
                }
            }

            if store.mode == .gradient {
                HStack(spacing: 8) {
                    gradientPicker("From", color: $store.gradientStart)
                    gradientPicker("To", color: $store.gradientEnd)
                }
                .transition(.opacity)
            } else {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(Color.panelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hint: LocalizedStringKey {
        switch store.mode {
        case .normal: return "Steady light in the color you picked."
        case .sos: return "Flashes the distress signal SOS in Morse code."
        case .candle: return "Warm, softly flickering light."
        case .disco: return "Changing party colors."
        case .rainbow: return "Slowly drifts through all colors."
        case .gradient: return "Fade"
        }
    }

    private func gradientPicker(_ title: LocalizedStringKey, color: Binding<LightColor>) -> some View {
        ColorPicker(selection: Binding(get: { color.wrappedValue.color },
                                       set: { color.wrappedValue = LightColor($0) }),
                    supportsOpacity: false) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: Metrics.touchTarget)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(Color.chipFill)
        )
    }
}

// MARK: - Timer

struct TimerSection: View {
    @ObservedObject var store: LightStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(spacing: 12) {
            if let end = store.timerEnd {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Light turns off in")
                            .font(.footnote)
                            .foregroundStyle(Color.panelSecondary)
                        Countdown(end: end)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                    }
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 8)
                    Button {
                        store.cancelTimer()
                        Haptics.selection()
                    } label: {
                        Label("Stop timer", systemImage: "xmark")
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(ChipStyle())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(minHeight: Metrics.controlHeight)
            } else {
                Text("Turn the light off automatically:")
                    .font(.footnote)
                    .foregroundStyle(Color.panelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(LightStore.timerChoices, id: \.self) { minutes in
                    Button {
                        store.startTimer(minutes: minutes)
                    } label: {
                        Text(Self.minutesText(minutes, width: .abbreviated))
                    }
                    .buttonStyle(ChipStyle(minHeight: Metrics.controlHeight))
                    .accessibilityLabel(Self.minutesText(minutes, width: .wide))
                }
            }
        }
    }
}

extension TimerSection {
    /// "5 min" / "5 minutes" in the user's language, with correct plural forms.
    static func minutesText(_ minutes: Int, width: Measurement<UnitDuration>.FormatStyle.UnitWidth) -> String {
        Measurement(value: Double(minutes), unit: UnitDuration.minutes)
            .formatted(.measurement(width: width, usage: .asProvided))
    }
}

/// Remaining time, refreshed once per second and only while visible.
struct Countdown: View {
    let end: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date).rounded(.up))
            Text(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond)))
                .monospacedDigit()
        }
    }
}
