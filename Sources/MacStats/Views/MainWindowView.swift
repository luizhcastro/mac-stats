import SwiftUI
import AppKit

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case cpu
    case gpu
    case memory
    case disk
    case network
    case battery
    case temperature
    case fans
    case processes
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:   return "Overview"
        case .cpu:         return "CPU"
        case .gpu:         return "GPU"
        case .memory:      return "Memory"
        case .disk:        return "Disk"
        case .network:     return "Network"
        case .battery:     return "Battery"
        case .temperature: return "Temperature"
        case .fans:        return "Fans"
        case .processes:   return "Processes"
        case .settings:    return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:   return "square.grid.2x2"
        case .cpu:         return "cpu"
        case .gpu:         return "display"
        case .memory:      return "memorychip"
        case .disk:        return "internaldrive"
        case .network:     return "network"
        case .battery:     return "battery.100"
        case .temperature: return "thermometer"
        case .fans:        return "fanblades"
        case .processes:   return "list.bullet.rectangle"
        case .settings:    return "gearshape"
        }
    }
}

/// Which hardware-dependent sidebar entries exist. Tracked separately so the
/// sidebar only re-renders when one of these flips, not on every tick.
private struct SidebarAvailability: Equatable {
    var gpu = false
    var battery = false
    var temperature = false
    var fans = false

    init() {}

    init(_ snap: SystemSnapshot) {
        gpu = snap.gpu.hasReadings
        battery = snap.battery.hasBattery
        temperature = snap.temperature.hasReadings
        fans = snap.fans.supported
    }
}

struct MainWindowView: View {
    // Not observed: each pane observes `stats` itself.
    let stats: SystemStats
    @ObservedObject var prefs: DisplayPreferences
    @State private var selection: SidebarSection = .dashboard
    @State private var available = SidebarAvailability()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    sidebarRow(.dashboard)
                }
                Section("Hardware") {
                    sidebarRow(.cpu)
                    if available.gpu {
                        sidebarRow(.gpu)
                    }
                    sidebarRow(.memory)
                    sidebarRow(.disk)
                    sidebarRow(.network)
                    if available.battery {
                        sidebarRow(.battery)
                    }
                    if available.temperature {
                        sidebarRow(.temperature)
                    }
                    if available.fans {
                        sidebarRow(.fans)
                    }
                }
                Section("Activity") {
                    sidebarRow(.processes)
                }
                Section {
                    sidebarRow(.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(detailBackground)
        }
        .navigationTitle(selection.title)
        .onAppear { available = SidebarAvailability(stats.snapshot) }
        .onReceive(stats.$snapshot) { snap in
            let next = SidebarAvailability(snap)
            if next != available { available = next }
        }
    }

    private var detailBackground: Color {
        if #available(macOS 26, *) { return .clear }
        return Color(nsColor: .windowBackgroundColor)
    }

    @ViewBuilder
    private func sidebarRow(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selection {
        case .dashboard: DashboardPane(stats: stats)
        case .cpu:       CPUPane(stats: stats)
        case .gpu:       GPUPane(stats: stats)
        case .memory:    MemoryPane(stats: stats)
        case .disk:      DiskPane(stats: stats)
        case .network:   NetworkPane(stats: stats)
        case .battery:   BatteryPane(stats: stats)
        case .temperature: TemperaturePane(stats: stats)
        case .fans:      FansPane(stats: stats)
        case .processes: ProcessesPane(stats: stats)
        case .settings:  SettingsPane(prefs: prefs)
        }
    }
}
