import SwiftUI

struct TopProcessesView: View {
    @ObservedObject var stats: SystemStats
    @State private var tab: Metric = .cpu

    enum Metric: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "RAM"
        case disk = "Disk"
        case network = "Net"
        var id: String { rawValue }
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let name: String
        let value: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: $tab) {
                ForEach(Metric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            RowsList(rows: rows(8))
                .equatable()
        }
    }

    private func rows(_ n: Int) -> [Row] {
        switch tab {
        case .cpu:
            return stats.processLeaders.cpu.prefix(n).map {
                Row(id: "\($0.id)", name: $0.name, value: String(format: "%.2f%%", $0.cpuPercent))
            }
        case .memory:
            return stats.processLeaders.memory.prefix(n).map {
                Row(id: "\($0.id)", name: $0.name, value: Fmt.bytes($0.memoryBytes))
            }
        case .disk:
            return stats.processLeaders.disk.prefix(n).map {
                Row(id: "\($0.id)", name: $0.name, value: Fmt.rate($0.diskReadPerSec + $0.diskWritePerSec))
            }
        case .network:
            return stats.processLeaders.network.prefix(n).map {
                Row(id: "\($0.id)", name: $0.name, value: Fmt.rate($0.bytesInPerSec + $0.bytesOutPerSec))
            }
        }
    }
}

private struct RowsList: View, Equatable {
    let rows: [TopProcessesView.Row]

    var body: some View {
        ForEach(rows) { r in
            HStack {
                Text(r.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(r.value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}
