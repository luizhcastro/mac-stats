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
                row(name: proc.name, value: processValue(proc))
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
        switch tab {
        case .cpu:
            return Array(stats.processLeaders.cpu.prefix(n))
        case .memory:
            return Array(stats.processLeaders.memory.prefix(n))
        case .disk:
            return Array(stats.processLeaders.disk.prefix(n))
        }
    }

    private func processValue(_ proc: ProcessMonitor.ProcStat) -> String {
        switch tab {
        case .cpu: return String(format: "%.2f%%", proc.cpuPercent)
        case .memory: return Fmt.bytes(proc.memoryBytes)
        case .disk: return Fmt.rate(proc.diskReadPerSec + proc.diskWritePerSec)
        }
    }
}
