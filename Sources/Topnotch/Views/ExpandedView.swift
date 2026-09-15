import SwiftUI

/// The body beneath the status strip: a labeled icon rail on the left (Settings pinned
/// at the bottom) and the selected widget on the right.
struct ExpandedView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        HStack(spacing: 10) {
            rail
                .frame(width: Theme.railWidth)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .id(viewModel.selectedTab)
                .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .padding(10)
    }

    /// A floating rounded rail rather than a full-height column with a divider — the
    /// whole body reads as separate modules sitting on black instead of one slab.
    ///
    /// All tabs are evenly spaced and vertically centered. Pinning Settings to the
    /// bottom with a Spacer overflowed the rail once every widget was enabled, which
    /// clipped it off the end.
    private var rail: some View {
        VStack(spacing: 2) {
            ForEach(viewModel.visibleTabs) { tab in
                RailButton(tab: tab, isSelected: viewModel.selectedTab == tab) {
                    viewModel.select(tab)
                }
            }
        }
        .padding(.vertical, 7)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .music:
            MusicWidget(controller: viewModel.mediaRemote, onOpenPlayer: { viewModel.collapse() })
        case .files:
            FileTrayWidget(store: viewModel.fileTray)
        case .notes:
            NotesWidget(store: viewModel.notesStore)
        case .calendar:
            CalendarWidget(manager: viewModel.calendarManager)
        case .timer:
            TimerWidget(timer: viewModel.pomodoro, settings: settings)
        case .weather:
            WeatherWidget(service: viewModel.weather, settings: settings)
        case .mirror:
            MirrorWidget(
                camera: viewModel.camera,
                isActive: viewModel.isExpanded && viewModel.selectedTab == .mirror
            )
        case .clipboard:
            ClipboardWidget(store: viewModel.clipboard)
        case .settings:
            SettingsView(settings: settings, calendar: viewModel.calendarManager)
        }
    }
}

private struct RailButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.ui(14, .medium))
                    .frame(height: 16)
                Text(tab.title)
                    .font(.ui(8.5, .medium))
            }
            .frame(width: 48, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.surfaceRaised : (hovering ? Theme.surface : .clear))
            )
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tab.title)
    }
}
