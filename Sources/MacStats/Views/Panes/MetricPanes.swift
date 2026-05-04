import SwiftUI

struct CPUPane: View {
    @ObservedObject var stats: SystemStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(
                    title: "CPU",
                    subtitle: "Last 60 seconds"
                )
                MetricCard(title: "Total Usage", icon: "cpu") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.percent(stats.cpu.usage))
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                        Spacer()
                    }
                    AreaSpark(values: stats.history.cpu, max: 100, color: .blue, height: 160)
                }
                HStack(spacing: 16) {
                    MetricCard(title: "User", icon: "person") {
                        Text(Fmt.percent(stats.cpu.user))
                            .font(.system(size: 24, weight: .semibold))
                            .monospacedDigit()
                    }
                    MetricCard(title: "System", icon: "gear") {
                        Text(Fmt.percent(stats.cpu.system))
                            .font(.system(size: 24, weight: .semibold))
                            .monospacedDigit()
                    }
                    MetricCard(title: "Idle", icon: "pause") {
                        Text(Fmt.percent(stats.cpu.idle))
                            .font(.system(size: 24, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                MetricCard(title: "Top CPU Processes", icon: "list.bullet") {
                    LeaderList(
                        rows: stats.processLeaders.cpu.prefix(8).map {
                            LeaderRow(
                                id: "\($0.id)",
                                pid: $0.id,
                                name: $0.name,
                                value: String(format: "%.2f%%", $0.cpuPercent)
                            )
                        }
                    )
                }
            }
            .padding(24)
        }
    }
}

struct MemoryPane: View {
    @ObservedObject var stats: SystemStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Memory", subtitle: "Allocation breakdown")
                MetricCard(title: "Used", icon: "memorychip") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.bytes(stats.memory.usedBytes))
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                        Text("of \(Fmt.bytes(stats.memory.totalBytes))")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    AreaSpark(values: stats.history.memoryPercent, max: 100, color: .green, height: 160)
                }
                HStack(spacing: 16) {
                    MetricCard(title: "Active", icon: "bolt") {
                        Text(Fmt.bytes(stats.memory.activeBytes))
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                    }
                    MetricCard(title: "Wired", icon: "lock") {
                        Text(Fmt.bytes(stats.memory.wiredBytes))
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                    }
                    MetricCard(title: "Compressed", icon: "rectangle.compress.vertical") {
                        Text(Fmt.bytes(stats.memory.compressedBytes))
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                    }
                    MetricCard(title: "Free", icon: "leaf") {
                        Text(Fmt.bytes(stats.memory.freeBytes))
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                MetricCard(title: "Pressure", icon: "gauge") {
                    HStack {
                        Text(Fmt.percent(stats.memory.pressurePercent))
                            .font(.system(size: 22, weight: .semibold))
                            .monospacedDigit()
                        Spacer()
                    }
                    ProgressView(value: stats.memory.pressurePercent, total: 100)
                }
                MetricCard(title: "Top Memory Processes", icon: "list.bullet") {
                    LeaderList(
                        rows: stats.processLeaders.memory.prefix(8).map {
                            LeaderRow(id: "\($0.id)", pid: $0.id, name: $0.name, value: Fmt.bytes($0.memoryBytes))
                        }
                    )
                }
            }
            .padding(24)
        }
    }
}

struct DiskPane: View {
    @ObservedObject var stats: SystemStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Disk", subtitle: "I/O throughput and capacity")
                MetricCard(title: "Throughput", icon: "internaldrive") {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Fmt.rate(stats.disk.readPerSec))
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.purple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Write")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Fmt.rate(stats.disk.writePerSec))
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.pink)
                        }
                        Spacer()
                    }
                    DualAreaSpark(
                        inValues: stats.history.diskRead,
                        outValues: stats.history.diskWrite,
                        max: ScaleHelper.niceMax(stats.history.diskRead + stats.history.diskWrite, minimum: 256 * 1024),
                        inColor: .purple,
                        outColor: .pink,
                        height: 160
                    )
                }
                if stats.disk.capacityBytes > 0 {
                    MetricCard(title: "Capacity", icon: "externaldrive") {
                        let used = stats.disk.capacityBytes - stats.disk.freeBytes
                        StatRow(label: "Used", value: Fmt.bytes(used))
                        StatRow(label: "Free", value: Fmt.bytes(stats.disk.freeBytes))
                        StatRow(label: "Total", value: Fmt.bytes(stats.disk.capacityBytes))
                        ProgressView(
                            value: Double(used),
                            total: Double(max(stats.disk.capacityBytes, 1))
                        )
                    }
                }
                MetricCard(title: "Top Disk Processes", icon: "list.bullet") {
                    LeaderList(
                        rows: stats.processLeaders.disk.prefix(8).map {
                            LeaderRow(
                                id: "\($0.id)",
                                pid: $0.id,
                                name: $0.name,
                                value: Fmt.rate($0.diskReadPerSec + $0.diskWritePerSec)
                            )
                        }
                    )
                }
            }
            .padding(24)
        }
    }
}

struct NetworkPane: View {
    @ObservedObject var stats: SystemStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Network", subtitle: "Live bandwidth across all interfaces")
                MetricCard(title: "Throughput", icon: "network") {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Fmt.rate(stats.network.bytesInPerSec))
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Fmt.rate(stats.network.bytesOutPerSec))
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                    DualAreaSpark(
                        inValues: stats.history.networkIn,
                        outValues: stats.history.networkOut,
                        max: ScaleHelper.niceMax(stats.history.networkIn + stats.history.networkOut, minimum: 64 * 1024),
                        height: 160
                    )
                }
                MetricCard(title: "Session Totals", icon: "sum") {
                    StatRow(label: "Total in", value: Fmt.bytes(stats.network.totalIn))
                    StatRow(label: "Total out", value: Fmt.bytes(stats.network.totalOut))
                }
                MetricCard(title: "Top Network Processes", icon: "list.bullet") {
                    LeaderList(
                        rows: stats.processLeaders.network.prefix(8).map {
                            LeaderRow(
                                id: "\($0.id)",
                                pid: $0.id,
                                name: $0.name,
                                value: Fmt.rate($0.bytesInPerSec + $0.bytesOutPerSec)
                            )
                        }
                    )
                }
            }
            .padding(24)
        }
    }
}

struct BatteryPane: View {
    @ObservedObject var stats: SystemStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Battery", subtitle: status)
                MetricCard(title: "Charge", icon: "battery.100") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.percent(stats.battery.percent))
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                        Spacer()
                    }
                    ProgressView(value: stats.battery.percent / 100.0)
                }
                MetricCard(title: "State", icon: "bolt.badge.clock") {
                    StatRow(label: "Charging", value: stats.battery.isCharging ? "Yes" : "No")
                    StatRow(label: "Plugged in", value: stats.battery.isPluggedIn ? "Yes" : "No")
                    if stats.battery.isCharging, let m = stats.battery.timeToFullMinutes {
                        StatRow(label: "Time to full", value: Fmt.minutes(m))
                    }
                    if let m = stats.battery.timeToEmptyMinutes {
                        StatRow(label: "Time remaining", value: Fmt.minutes(m))
                    }
                }
            }
            .padding(24)
        }
    }

    private var status: String {
        if !stats.battery.hasBattery { return "No battery present" }
        if stats.battery.isCharging { return "Charging" }
        if stats.battery.isPluggedIn { return "Plugged in" }
        return "On battery"
    }
}

struct LeaderRow: Identifiable, Equatable {
    let id: String
    let pid: Int32
    let name: String
    let value: String
}

struct LeaderList: View {
    let rows: [LeaderRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { r in
                HStack {
                    Text(r.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text("\(r.pid)")
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(r.value)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 70, alignment: .trailing)
                    Menu {
                        Button("Quit") {
                            ProcessKill.confirmAndKill(pid: r.pid, name: r.name, mode: .quit)
                        }
                        Button("Force Kill") {
                            ProcessKill.confirmAndKill(pid: r.pid, name: r.name, mode: .forceKill)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                .font(.callout)
                .padding(.vertical, 6)
                .contextMenu {
                    Button("Quit \(r.name)") {
                        ProcessKill.confirmAndKill(pid: r.pid, name: r.name, mode: .quit)
                    }
                    Button("Force Kill \(r.name)") {
                        ProcessKill.confirmAndKill(pid: r.pid, name: r.name, mode: .forceKill)
                    }
                }
                if r.id != rows.last?.id {
                    Divider().opacity(0.4)
                }
            }
        }
    }
}
