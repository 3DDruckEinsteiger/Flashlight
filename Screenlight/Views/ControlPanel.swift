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

    var body: some View {
        // Falls back to scrolling when the panel does not fit
        // (landscape phones, very large text).
        ViewThatFits(in: .vertical) {
            content
            ScrollView(showsIndicators: false) { content }
        }
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
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var content: some View {
        VStack(spacing: 16) {
            if store.removedFavorite != nil {
                undoBar
            }
            tabs
            Group {
                switch selectedTab {
                case .color: ColorSection(store: store)
                case .mode: ModeSection(store: store)
                case .timer: TimerSection(store: store)
                }
            }
            brightness
            actions
        }
        .animation(.easeInOut(duration: 0.2), value: store.removedFavorite?.favorite.id)
        .animation(.easeInOut(duration: 0.2), value: store.mode)
    }

    // MARK: Tabs

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(PanelTab.allCases) { tab in
                Button {
                    selectedTab = tab
                    Haptics.selection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                        if tab == .timer, let end = store.timerEnd {
                            Countdown(end: end)
                        } else {
                            Text(tab.title)
                        }
                    }
                }
                .buttonStyle(ChipStyle(isSelected: selectedTab == tab))
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
                Label(store.isOn ? "Turn off" : "Turn on", systemImage: "power")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(store.isOn ? Color.black : Color.white)
                    .frame(maxWidth: .infinity, minHeight: Metrics.controlHeight + 4)
                    .background(
                        Capsule().fill(store.isOn ? Color.white : Color.white.opacity(0.18))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(store.isOn ? 0 : 0.6), lineWidth: 1.5)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Light"))
            .accessibilityValue(store.isOn ? Text("On") : Text("Off"))
            .accessibilityHint(store.isOn ? Text("Turn off") : Text("Turn on"))

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
        }
    }

    // MARK: Undo

    private var undoBar: some View {
        HStack(spacing: 12) {
            Label("Favorite removed", systemImage: "trash")
                .font(.subheadline)
            Spacer(minLength: 8)
            Button("Undo") {
                store.undoRemoveFavorite()
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 12)
            .frame(minHeight: Metrics.touchTarget)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(Color.chipFill)
        )
        .transition(.opacity)
    }
}
