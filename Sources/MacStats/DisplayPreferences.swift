import Foundation
import Combine

enum BarMetric: String, CaseIterable, Identifiable, Codable {
    case cpu, ram, disk, network
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .disk: return "Disk"
        case .network: return "Network"
        }
    }
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        }
    }
}

@MainActor
final class DisplayPreferences: ObservableObject {
    private let key = "menubar.metrics"
    private static let order: [BarMetric] = [.cpu, .ram, .disk, .network]

    @Published private(set) var selected: [BarMetric] = [.cpu]

    init() {
        load()
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
