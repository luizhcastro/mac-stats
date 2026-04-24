import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var stats: SystemStats
    @ObservedObject var prefs: DisplayPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cpuSection
            Divider()
            memorySection
            Divider()
            networkSection
            Divider()
            diskSection
            if stats.battery.hasBattery {
                Divider()
                batterySection
            }
            Divider()
            TopProcessesView(stats: stats)
            Divider()
            MenuBarPrefsView(prefs: prefs)
            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                    .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.headline)
                Spacer()
                Text(Fmt.percent(stats.cpu.usage))
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("user \(Fmt.percent(stats.cpu.user))")
                Text("sys \(Fmt.percent(stats.cpu.system))")
                Text("idle \(Fmt.percent(stats.cpu.idle))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Sparkline(values: stats.cpuHistory, max: 100)
                .frame(height: 28)
        }
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.headline)
                Spacer()
                Text("\(Fmt.bytes(stats.memory.usedBytes)) / \(Fmt.bytes(stats.memory.totalBytes))")
                    .monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("wired \(Fmt.bytes(stats.memory.wiredBytes))")
                Text("comp \(Fmt.bytes(stats.memory.compressedBytes))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: stats.memory.pressurePercent, total: 100)
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Network", systemImage: "network")
                .font(.headline)
            HStack {
                Image(systemName: "arrow.down")
                Text(Fmt.rate(stats.network.bytesInPerSec))
                    .monospacedDigit()
                Spacer()
                Image(systemName: "arrow.up")
                Text(Fmt.rate(stats.network.bytesOutPerSec))
                    .monospacedDigit()
            }
            .font(.callout)
        }
    }

    private var diskSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Disk", systemImage: "internaldrive")
                    .font(.headline)
                Spacer()
                if stats.disk.capacityBytes > 0 {
                    Text("\(Fmt.bytes(stats.disk.capacityBytes - stats.disk.freeBytes)) / \(Fmt.bytes(stats.disk.capacityBytes))")
                        .monospacedDigit()
                        .font(.caption)
                }
            }
            HStack {
                Image(systemName: "arrow.down")
                Text(Fmt.rate(stats.disk.readPerSec))
                    .monospacedDigit()
                Spacer()
                Image(systemName: "arrow.up")
                Text(Fmt.rate(stats.disk.writePerSec))
                    .monospacedDigit()
            }
            .font(.callout)
        }
    }

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Battery", systemImage: batteryIcon)
                    .font(.headline)
                Spacer()
                Text(Fmt.percent(stats.battery.percent))
                    .monospacedDigit()
            }
            if stats.battery.isCharging, let mins = stats.battery.timeToFullMinutes {
                Text("Full in \(Fmt.minutes(mins))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let mins = stats.battery.timeToEmptyMinutes {
                Text("\(Fmt.minutes(mins)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var batteryIcon: String {
        if stats.battery.isCharging { return "battery.100.bolt" }
        let p = stats.battery.percent
        if p > 75 { return "battery.100" }
        if p > 50 { return "battery.75" }
        if p > 25 { return "battery.50" }
        if p > 10 { return "battery.25" }
        return "battery.0"
    }
}

struct Sparkline: View {
    let values: [Double]
    let max: Double

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(min(v, max) / max))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.accentColor, lineWidth: 1.5)
        }
    }
}
