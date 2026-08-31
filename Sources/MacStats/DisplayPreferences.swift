import Foundation
import Combine
import AppKit

enum BarMetric: String, CaseIterable, Identifiable, Codable {
    case cpu, temperature, ram, disk, network, appIcon
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cpu: return "CPU"
        case .temperature: return "Temp"
        case .ram: return "RAM"
        case .disk: return "Disk"
        case .network: return "Network"
        case .appIcon: return "App icon"
        }
    }
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .temperature: return "thermometer"
        case .ram: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .appIcon: return "app.badge"
        }
    }
}

@MainActor
final class DisplayPreferences: ObservableObject {
    private let key = "menubar.metrics"
    private let dockKey = "dock.icon"
    private static let order: [BarMetric] = [.cpu, .temperature, .ram, .disk, .network, .appIcon]

    @Published private(set) var selected: [BarMetric] = [.cpu]

    @Published var showDockIcon: Bool = false {
        didSet {
            guard oldValue != showDockIcon else { return }
            UserDefaults.standard.set(showDockIcon, forKey: dockKey)
            applyActivationPolicy()
        }
    }

    init() {
        load()
        showDockIcon = UserDefaults.standard.bool(forKey: dockKey)
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    func toggle(_ metric: BarMetric) {
        if selected.contains(metric) {
            guard selected.count > 1 else { return }
            selected.removeAll { $0 == metric }
        } else {
            selected.append(metric)
            selected.sort { Self.order.firstIndex(of: $0)! < Self.order.firstIndex(of: $1)! }
        }
        save()
    }

    func isSelected(_ metric: BarMetric) -> Bool {
        selected.contains(metric)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BarMetric].self, from: data),
              !decoded.isEmpty else {
            return
        }
        selected = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(selected) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
