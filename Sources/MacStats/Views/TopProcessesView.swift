import SwiftUI

struct TopProcessesView: View {
    @ObservedObject var stats: SystemStats
    @State private var tab: Metric = .cpu

    enum Metric: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "RAM"
        case disk = "Disk"
        var id: String { rawValue }
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

            ForEach(topN(8)) { proc in
                HStack {
                    Text(proc.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text(value(for: proc))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    private func topN(_ n: Int) -> [ProcessMonitor.ProcStat] {
        let sorted: [ProcessMonitor.ProcStat]
        switch tab {
        case .cpu:
            sorted = stats.processes.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory:
            sorted = stats.processes.sorted { $0.memoryBytes > $1.memoryBytes }
        case .disk:
            sorted = stats.processes.sorted {
                ($0.diskReadPerSec + $0.diskWritePerSec) > ($1.diskReadPerSec + $1.diskWritePerSec)
            }
        }
        return Array(sorted.prefix(n))
    }

    private func value(for proc: ProcessMonitor.ProcStat) -> String {
        switch tab {
        case .cpu: return String(format: "%.1f%%", proc.cpuPercent)
        case .memory: return Fmt.bytes(proc.memoryBytes)
        case .disk: return Fmt.rate(proc.diskReadPerSec + proc.diskWritePerSec)
        }
    }
}
