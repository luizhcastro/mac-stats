import SwiftUI

struct DashboardPane: View {
    @ObservedObject var stats: SystemStats

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Overview",
                    subtitle: "Live snapshot of system activity"
                )
                LazyVGrid(columns: columns, spacing: 16) {
                    cpuCard
                    memoryCard
                    networkCard
                    diskCard
                    if stats.battery.hasBattery {
                        batteryCard
                    }
                }
            }
            .padding(24)
        }
    }

    private var cpuCard: some View {
        MetricCard(title: "CPU", icon: "cpu") {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.percent(stats.cpu.usage))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Text("user \(Fmt.percent(stats.cpu.user)) · sys \(Fmt.percent(stats.cpu.system))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            AreaSpark(values: stats.history.cpu, max: 100, color: .blue)
        }
    }

    private var memoryCard: some View {
        MetricCard(title: "Memory", icon: "memorychip") {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Fmt.bytes(stats.memory.usedBytes))")
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Text("/ \(Fmt.bytes(stats.memory.totalBytes))")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("pressure \(Fmt.percent(stats.memory.pressurePercent))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            AreaSpark(values: stats.history.memoryPercent, max: 100, color: .green)
        }
    }

    private var networkCard: some View {
        MetricCard(title: "Network", icon: "network") {
            HStack(spacing: 18) {
                rateBlock(symbol: "arrow.down", color: .blue, rate: stats.network.bytesInPerSec)
                rateBlock(symbol: "arrow.up", color: .orange, rate: stats.network.bytesOutPerSec)
            }
            DualAreaSpark(
                inValues: stats.history.networkIn,
                outValues: stats.history.networkOut,
                max: ScaleHelper.niceMax(stats.history.networkIn + stats.history.networkOut, minimum: 64 * 1024)
            )
        }
    }

    private var diskCard: some View {
        MetricCard(title: "Disk", icon: "internaldrive") {
            HStack(spacing: 18) {
                rateBlock(symbol: "arrow.down", color: .purple, rate: stats.disk.readPerSec)
                rateBlock(symbol: "arrow.up", color: .pink, rate: stats.disk.writePerSec)
            }
            DualAreaSpark(
                inValues: stats.history.diskRead,
                outValues: stats.history.diskWrite,
                max: ScaleHelper.niceMax(stats.history.diskRead + stats.history.diskWrite, minimum: 256 * 1024),
                inColor: .purple,
                outColor: .pink
            )
        }
    }

    private var batteryCard: some View {
        MetricCard(title: "Battery", icon: "battery.100") {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.percent(stats.battery.percent))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Text(batteryStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: stats.battery.percent / 100.0)
                .progressViewStyle(.linear)
        }
    }

    private var batteryStatus: String {
        if stats.battery.isCharging, let m = stats.battery.timeToFullMinutes { return "Full in \(Fmt.minutes(m))" }
        if let m = stats.battery.timeToEmptyMinutes { return "\(Fmt.minutes(m)) remaining" }
        return stats.battery.isPluggedIn ? "Plugged in" : "On battery"
    }

    private func rateBlock(symbol: String, color: Color, rate: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(Fmt.rate(rate))
                .monospacedDigit()
        }
        .font(.callout)
    }
}
