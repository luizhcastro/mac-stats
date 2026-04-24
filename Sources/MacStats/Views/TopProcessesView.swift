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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: $tab) {
                ForEach(Metric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if tab == .network {
                ForEach(topNetwork(8)) { proc in
                    row(name: proc.name, value: Fmt.rate(proc.bytesInPerSec + proc.bytesOutPerSec))
                }
                if stats.networkProcesses.isEmpty {
                    Text("Collecting…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(topN(8)) { proc in
                    row(name: proc.name, value: processValue(proc))
                }
            }
        }
    }

    @ViewBuilder
    private func row(name: String, value: String) -> some View {
        HStack {
            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
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
        case .network:
            sorted = []
        }
        return Array(sorted.prefix(n))
    }

    private func topNetwork(_ n: Int) -> [NetworkProcessMonitor.ProcStat] {
        let sorted = stats.networkProcesses.sorted {
            ($0.bytesInPerSec + $0.bytesOutPerSec) > ($1.bytesInPerSec + $1.bytesOutPerSec)
        }
        return Array(sorted.prefix(n))
    }

    private func processValue(_ proc: ProcessMonitor.ProcStat) -> String {
        switch tab {
        case .cpu: return String(format: "%.2f%%", proc.cpuPercent)
        case .memory: return Fmt.bytes(proc.memoryBytes)
        case .disk: return Fmt.rate(proc.diskReadPerSec + proc.diskWritePerSec)
        case .network: return ""
        }
    }
}
