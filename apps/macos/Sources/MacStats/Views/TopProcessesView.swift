import SwiftUI

struct TopProcessesView: View {
    @ObservedObject var stats: SystemStats
    @State private var tab: Metric

    init(stats: SystemStats, initialTab: Metric = .cpu) {
        self.stats = stats
        _tab = State(initialValue: initialTab)
    }

    enum Metric: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "RAM"
        case disk = "Disk"
        case network = "Net"
        case energy = "Energy"
        var id: String { rawValue }

        init(_ metric: BarMetric) {
            switch metric {
            case .ram: self = .memory
            case .disk: self = .disk
            case .network: self = .network
            case .cpu, .temperature, .appIcon: self = .cpu
            }
        }
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let name: String
        let value: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SlidingSegmented(options: Metric.allCases, selection: $tab, label: \.rawValue)
            .onAppear { stats.setEnergyTrackingEnabled(tab == .energy) }
            .onChange(of: tab) { newValue in
                stats.setEnergyTrackingEnabled(newValue == .energy)
            }
            .onDisappear { stats.setEnergyTrackingEnabled(false) }

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
        case .energy:
            return stats.processLeaders.energy.prefix(n).map {
                Row(id: "\($0.id)", name: $0.name, value: String(format: "%.1f EI", $0.energyImpact))
            }
        }
    }
}

private struct RowsList: View, Equatable {
    let rows: [TopProcessesView.Row]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated static func == (lhs: RowsList, rhs: RowsList) -> Bool { lhs.rows == rhs.rows }

    var body: some View {
        // Rows are keyed by process, so switching tabs or a re-rank slides a
        // process to its new place; processes entering/leaving the top fade.
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { r in
                row(r)
                    .transition(.opacity)
            }
        }
        .animation(Motion.spring(reduceMotion: reduceMotion), value: rows.map(\.id))
    }

    private func row(_ r: TopProcessesView.Row) -> some View {
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
