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
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var stats: SystemStats
    @State private var selection: SidebarSection = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    sidebarRow(.dashboard)
                }
                Section("Hardware") {
                    sidebarRow(.cpu)
                    if stats.gpu.hasReadings {
                        sidebarRow(.gpu)
                    }
                    sidebarRow(.memory)
                    sidebarRow(.disk)
                    sidebarRow(.network)
                    if stats.battery.hasBattery {
                        sidebarRow(.battery)
                    }
                    if stats.temperature.hasReadings {
                        sidebarRow(.temperature)
                    }
                    if stats.fans.supported {
                        sidebarRow(.fans)
                    }
                }
                Section("Activity") {
                    sidebarRow(.processes)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle(selection.title)
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
        }
    }
}
