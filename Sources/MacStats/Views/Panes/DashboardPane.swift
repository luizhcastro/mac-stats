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
                    if stats.temperature.hasReadings {
                        temperatureCard
                    }
                }
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
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            AreaSpark(values: stats.history.cpu.minute, max: 100, color: .blue)
        }
    }

    private var memoryCard: some View {
        card("Memory", icon: "memorychip") {
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
            Spacer(minLength: 0)
            AreaSpark(values: stats.history.memoryPercent.minute, max: 100, color: .green)
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
            ProgressView(value: stats.battery.percent / 100.0)
                .progressViewStyle(.linear)
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
            Text(Fmt.rate(rate))
                .monospacedDigit()
        }
        .font(.callout)
    }
}
