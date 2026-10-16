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
                    subtitle: "Up \(Fmt.uptime(ProcessInfo.processInfo.systemUptime))"
                )
                LazyVGrid(columns: columns, spacing: 16) {
                    cpuCard
                    memoryCard
                    networkCard
                    diskCard
                    if stats.battery.hasBattery {
                        batteryCard
                    }
                    if stats.temperature.hasReadings {
                        temperatureCard
                    }
                }
                topProcessesCard
                    .padding(.top, 16)
            }
            .padding(24)
        }
    }

    private var cpuCard: some View {
        card("CPU", icon: "cpu") {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.percent(stats.cpu.usage))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Text("user \(Fmt.percent(stats.cpu.user)) · sys \(Fmt.percent(stats.cpu.system))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            AreaSpark(values: stats.history.cpu.minute, max: 100, color: .blue)
                .equatable()
        }
    }

    private var memoryCard: some View {
        card("Memory", icon: "memorychip") {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Fmt.bytes(stats.memory.usedBytes))")
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Text("/ \(Fmt.totalBytes(stats.memory.totalBytes))")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("pressure \(Fmt.percent(stats.memory.pressurePercent))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            AreaSpark(values: stats.history.memoryPercent.minute, max: 100, color: .green)
                .equatable()
        }
    }

    private var networkCard: some View {
        card("Network", icon: "network") {
            HStack(spacing: 18) {
                rateBlock(symbol: "arrow.down", color: .blue, rate: stats.network.bytesInPerSec)
                rateBlock(symbol: "arrow.up", color: .orange, rate: stats.network.bytesOutPerSec)
            }
            Spacer(minLength: 0)
            DualAreaSpark(
                inValues: stats.history.networkIn.minute,
                outValues: stats.history.networkOut.minute,
                max: ScaleHelper.niceMax(stats.history.networkIn.minute + stats.history.networkOut.minute, minimum: 64 * 1024)
            )
            .equatable()
        }
    }

    private var diskCard: some View {
        card("Disk", icon: "internaldrive") {
            HStack(spacing: 18) {
                rateBlock(symbol: "arrow.down", color: .purple, rate: stats.disk.readPerSec)
                rateBlock(symbol: "arrow.up", color: .pink, rate: stats.disk.writePerSec)
            }
            Spacer(minLength: 0)
            DualAreaSpark(
                inValues: stats.history.diskRead.minute,
                outValues: stats.history.diskWrite.minute,
                max: ScaleHelper.niceMax(stats.history.diskRead.minute + stats.history.diskWrite.minute, minimum: 256 * 1024),
                inColor: .purple,
                outColor: .pink
            )
            .equatable()
        }
    }

    private var batteryCard: some View {
        card("Battery", icon: "battery.100") {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.percent(stats.battery.percent))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Text(batteryStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // Same 30-minute charge ring as the Battery pane, minus the unfilled
            // slots (so it doesn't start as a jump from 0); a bar until two samples land
            let charge = Array(stats.history.batteryPercent.drop { $0 <= 0 })
            if charge.count > 1 {
                AreaSpark(
                    values: charge,
                    max: 100,
                    color: stats.battery.isCharging ? .green : .blue
                )
                .equatable()
            } else {
                ProgressView(value: stats.battery.percent / 100.0)
                    .progressViewStyle(.linear)
            }
        }
    }

    /// The hogs, so the Overview answers "what's using it" without a click
    private var topProcessesCard: some View {
        MetricCard(title: "Top CPU processes", icon: "list.bullet") {
            LeaderList(
                rows: stats.processLeaders.cpu.prefix(5).map {
                    LeaderRow(id: "\($0.id)", pid: $0.id, name: $0.name, value: String(format: "%.2f%%", $0.cpuPercent))
                }
            )
        }
    }

    private var temperatureCard: some View {
        card("Temperature", icon: "thermometer") {
            HStack(alignment: .firstTextBaseline) {
                Text(TemperaturePane.format(stats.temperature.cpuCelsius))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(TemperaturePane.color(for: stats.temperature.cpuCelsius))
                Spacer()
                Text(stats.thermal.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            AreaSpark(
                values: stats.history.temperature.minute,
                max: ScaleHelper.niceMax(stats.history.temperature.minute, minimum: 80),
                color: .orange
            )
            .equatable()
        }
    }

    /// Fixed body height so every Overview card renders at the same size:
    /// big-number row (~34pt) + 10pt spacing + 80pt spark, plus slack.
    private static let cardBodyHeight: CGFloat = 128

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        MetricCard(title: title, icon: icon) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.cardBodyHeight, alignment: .top)
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
            // Reserve the widest form ("999.9 KB/s") so the ↑ block doesn't shift when ↓ changes unit
            Text(Fmt.rate(rate))
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .leading)
        }
        .font(.callout)
    }
}
