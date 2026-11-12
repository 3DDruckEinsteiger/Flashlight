import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case color, mode, timer

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .color: return "Color"
        case .mode: return "Mode"
        case .timer: return "Timer"
        }
    }

    var symbol: String {
        switch self {
        case .color: return "paintpalette.fill"
        case .mode: return "wand.and.stars"
        case .timer: return "timer"
        }
    }
}

/// The control panel at the bottom of the screen. Everything is within reach
/// of the thumb; the most important control – power – sits at the very bottom.
struct ControlPanel: View {
    @ObservedObject var store: LightStore
    /// Hides the panel so that only the light is visible.
    let onLightOnly: () -> Void

    @AppStorage("selectedTab") private var selectedTab: PanelTab = .color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        content
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .fill(Color(white: 0.09).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        .foregroundStyle(Color.white)
        .tint(.white)
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var content: some View {
        VStack(spacing: 16) {
            if store.removedFavorite != nil {
                undoBar
            }
            tabs
            // Only the middle part scrolls when space is tight (small phones, landscape,
            // very large text). Brightness and power always stay on screen.
            ViewThatFits(in: .vertical) {
                section
                ScrollView(showsIndicators: false) { section }
            }
            brightness
            actions
        }
        .animation(.easeInOut(duration: 0.2), value: store.removedFavorite?.favorite.id)
        .animation(.easeInOut(duration: 0.2), value: store.mode)
    }

    @ViewBuilder
    private var section: some View {
        switch selectedTab {
        case .color: ColorSection(store: store)
        case .mode: ModeSection(store: store)
        case .timer: TimerSection(store: store)
        }
    }

    // MARK: Tabs

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(PanelTab.allCases) { tab in
                Button {
                    selectedTab = tab
                    Haptics.selection()
                } label: {
                    // Very large text: icon above the word, so the word keeps its width.
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 6))
                    layout {
                        Image(systemName: tab.symbol)
                        if tab == .timer, let end = store.timerEnd {
                            Countdown(end: end)
                        } else {
                            Text(tab.title)
                        }
                    }
                    .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
                }
                .buttonStyle(ChipStyle(isSelected: selectedTab == tab))
                .accessibilityLabel(Text(tab.title))
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
            }
        }
    }

    // MARK: Brightness

    private var brightnessText: String {
        store.brightness.formatted(.percent.precision(.fractionLength(0)))
    }

    private var brightness: some View {
        HStack(spacing: 12) {
            LightSlider(
                value: Binding(get: { store.brightness }, set: { store.setBrightness($0) }),
                range: LightStore.brightnessRange,
                symbol: "sun.max.fill",
                label: Text("Brightness"),
                valueText: brightnessText
            )
            .accessibilityIdentifier("brightness")
            Text(brightnessText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    // MARK: Power

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                store.togglePower()
            } label: {
                powerLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Light"))
            .accessibilityValue(store.isOn ? Text("On") : Text("Off"))
            .accessibilityHint(store.isOn ? Text("Turn off") : Text("Turn on"))
            .accessibilityIdentifier("power")

            Button(action: onLightOnly) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold))
                    Text("Light only")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 12)
                .frame(minWidth: 84, minHeight: Metrics.controlHeight + 4)
                .background(Capsule().fill(Color.chipFill))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Hides the controls. Tap the light to show them again."))
            .accessibilityIdentifier("lightOnly")
        }
    }

    private var powerLabel: some View {
        let isOn = store.isOn
        let fill: Color = isOn ? .white : .white.opacity(0.18)
        let border: Color = .white.opacity(isOn ? 0 : 0.6)
        return Label(isOn ? "Turn off" : "Turn on", systemImage: "power")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(isOn ? Color.black : Color.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Metrics.controlHeight + 4)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1.5))
            .contentShape(Capsule())
    }

    // MARK: Undo

    private var undoBar: some View {
        HStack(spacing: 12) {
            Label("Favorite removed", systemImage: "trash")
                .font(.subheadline)
            Spacer(minLength: 8)
            Button {
                store.undoRemoveFavorite()
            } label: {
                Text("Undo")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(minWidth: Metrics.touchTarget, minHeight: Metrics.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("undo")
        }
        .padding(.leading, 12)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(Color.chipFill)
        )
        .transition(.opacity)
    }
}
