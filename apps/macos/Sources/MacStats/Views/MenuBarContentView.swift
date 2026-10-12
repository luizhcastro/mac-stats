import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var stats: SystemStats
    @ObservedObject var prefs: DisplayPreferences
    var focus: BarMetric = .cpu
    var openWindow: () -> Void = {}
    @ObservedObject private var updates = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let version = updates.availableVersion {
                updateBanner(version)
            }
            Divider()
            cpuSection
            if stats.temperature.hasReadings {
                Divider()
                temperatureSection
            }
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
            if #available(macOS 14.4, *) {
                Divider()
                SoundSection()
            }
            Divider()
            PopoverSection("processes") {
                Label("Top processes", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .fixedSize()
            } detail: {
                TopProcessesView(stats: stats, initialTab: .init(focus))
            }
            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                    .buttonStyle(.borderless)
            }
        }
        // One line per row everywhere: truncate, never wrap (a wrapped title or
        // caption row breaks the section grid). No minimumScaleFactor: the
        // popover's self-sizing pass applied it even with room to spare, so
        // fonts shrank whenever every section was collapsed.
        .lineLimit(1)
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("MacStats")
                    .font(.headline)
                Text("System monitor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openWindow()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(.borderless)
            .help("Open main window")
        }
    }

    private func updateBanner(_ version: String) -> some View {
        HStack {
            Label("MacStats \(version) is available", systemImage: "arrow.down.circle.fill")
                .font(.caption)
            Spacer()
            Button("Update") { updates.checkForUpdates() }
                .controlSize(.small)
        }
    }

    private var cpuSection: some View {
        PopoverSection("cpu") {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.headline)
                    .fixedSize()
                Spacer()
                Text(Fmt.percent(stats.cpu.usage))
                    .monospacedDigit()
            }
        } detail: {
            HStack(spacing: 10) {
                Text("user \(Fmt.percent(stats.cpu.user))")
                Text("sys \(Fmt.percent(stats.cpu.system))")
                Text("idle \(Fmt.percent(stats.cpu.idle))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            HStack(spacing: 10) {
                let l = stats.cpu.loadAverage
                Text(String(format: "load %.2f / %.2f / %.2f", l.one, l.five, l.fifteen))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            Sparkline(values: stats.cpuHistory, max: 100)
                .frame(height: 28)
        }
    }

    private var temperatureSection: some View {
        PopoverSection("temperature", expandedByDefault: false) {
            HStack {
                Label("Temperature", systemImage: "thermometer")
                    .font(.headline)
                    .fixedSize()
                Spacer()
                Text(Self.tempText(stats.temperature.cpuCelsius, fallback: stats.temperature.maxCelsius))
                    .monospacedDigit()
            }
        } detail: {
            HStack(spacing: 10) {
                if stats.temperature.cpuCelsius > 0 {
                    Text("CPU \(Self.tempText(stats.temperature.cpuCelsius))")
                }
                if stats.temperature.gpuCelsius > 0 {
                    Text("GPU \(Self.tempText(stats.temperature.gpuCelsius))")
                }
                if stats.temperature.maxCelsius > 0 {
                    Text("Max \(Self.tempText(stats.temperature.maxCelsius))")
                }
                Spacer()
                Text("· \(stats.thermal.label)")
                    .foregroundStyle(thermalPressureColor)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var thermalPressureColor: Color {
        switch stats.thermal {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }

    private static func tempText(_ celsius: Double, fallback: Double = 0) -> String {
        let v = celsius > 0 ? celsius : fallback
        if v <= 0 { return "--°" }
        return String(format: "%.0f°C", v)
    }

    private var memorySection: some View {
        PopoverSection("memory", expandedByDefault: false) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.headline)
                    .fixedSize()
                Spacer()
                Text("\(Fmt.bytes(stats.memory.usedBytes)) / \(Fmt.totalBytes(stats.memory.totalBytes))")
                    .monospacedDigit()
            }
        } detail: {
            HStack(spacing: 10) {
                Text("wired \(Fmt.bytes(stats.memory.wiredBytes))")
                Text("comp \(Fmt.bytes(stats.memory.compressedBytes))")
                if stats.memory.swapUsedBytes > 0 {
                    Text("swap \(Fmt.bytes(stats.memory.swapUsedBytes))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            ProgressView(value: stats.memory.pressurePercent, total: 100)
        }
    }

    private var networkSection: some View {
        HStack {
            Label("Network", systemImage: "network")
                .font(.headline)
                .fixedSize()
                .padding(.leading, PopoverSection<EmptyView, EmptyView>.chevronWidth)
            Spacer()
            Image(systemName: "arrow.down")
            Text(Fmt.rate(stats.network.bytesInPerSec))
                .monospacedDigit()
            Image(systemName: "arrow.up")
                .padding(.leading, 8)
            Text(Fmt.rate(stats.network.bytesOutPerSec))
                .monospacedDigit()
        }
        .font(.callout)
    }

    private var diskSection: some View {
        PopoverSection("disk", expandedByDefault: false) {
            HStack {
                Label("Disk", systemImage: "internaldrive")
                    .font(.headline)
                    .fixedSize()
                Spacer()
                if stats.disk.capacityBytes > 0 {
                    Text("\(Fmt.bytes(stats.disk.capacityBytes - stats.disk.freeBytes)) / \(Fmt.totalBytes(stats.disk.capacityBytes))")
                        .monospacedDigit()
                }
            }
        } detail: {
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
        PopoverSection("battery", expandedByDefault: false) {
            HStack {
                Label("Battery", systemImage: batteryIcon)
                    .font(.headline)
                    .fixedSize()
                Spacer()
                Text(Fmt.percent(stats.battery.percent))
                    .monospacedDigit()
            }
        } detail: {
            if stats.battery.isCharging, let mins = stats.battery.timeToFullMinutes {
                Text("Full in \(Fmt.minutes(mins))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else if let mins = stats.battery.timeToEmptyMinutes {
                Text("\(Fmt.minutes(mins)) remaining")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if let healthLine {
                Text(healthLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var healthLine: String? {
        var parts: [String] = []
        if let cycles = stats.battery.cycleCount { parts.append("\(cycles) cycles") }
        if let h = stats.battery.healthPercent { parts.append("\(Fmt.percent(h)) health") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

/// Popover section with a clickable header that collapses the detail below
/// it. Collapsed state persists per section (`popover.expanded.<key>`), so the
/// popover stays as short as the user left it.
struct PopoverSection<Header: View, Detail: View>: View {
    static var chevronWidth: CGFloat { 14 }

    @AppStorage private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let header: Header
    private let detail: Detail

    init(_ key: String, expandedByDefault: Bool = true,
         @ViewBuilder header: () -> Header, @ViewBuilder detail: () -> Detail) {
        _expanded = AppStorage(wrappedValue: expandedByDefault, "popover.expanded.\(key)")
        self.header = header()
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(Motion.spring(reduceMotion: reduceMotion)) { expanded.toggle() }
            } label: {
                HStack(spacing: 0) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: Self.chevronWidth, alignment: .leading)
                    header
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                detail
                    .padding(.leading, Self.chevronWidth)
                    .transition(Motion.reveal(reduceMotion: reduceMotion))
            }
        }
    }
}
