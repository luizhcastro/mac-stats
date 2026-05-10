import SwiftUI

struct CPUPane: View {
    @ObservedObject var stats: SystemStats
    @State private var range: HistoryRange = .minute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(
                    title: "CPU",
                    subtitle: "History range: \(range.label)",
                    trailing: AnyView(HistoryRangePicker(selection: $range))
                )
                MetricCard(title: "Total Usage", icon: "cpu") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.percent(stats.cpu.usage))
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                        Spacer()
                    }
                    AreaSpark(values: stats.history.cpu.values(for: range), max: 100, color: .blue, height: 160)
                }
                if !stats.cpu.cores.isEmpty {
                    MetricCard(title: "Per-core Usage", icon: "rectangle.split.3x1") {
                        CoreBars(cores: stats.cpu.cores, height: 90)
                        CoreLegend(cores: stats.cpu.cores)
                            .padding(.top, 4)
                    }
                }
                MetricCard(title: "Load Average", icon: "gauge.with.dots.needle.50percent") {
                    HStack(spacing: 28) {
                        LoadAvgStat(label: "1 min", value: stats.cpu.loadAverage.one)
                        LoadAvgStat(label: "5 min", value: stats.cpu.loadAverage.five)
                        LoadAvgStat(label: "15 min", value: stats.cpu.loadAverage.fifteen)
                        Spacer()
                    }
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
    @State private var range: HistoryRange = .minute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(
                    title: "Memory",
                    subtitle: "History range: \(range.label)",
                    trailing: AnyView(HistoryRangePicker(selection: $range))
                )
                MetricCard(title: "Used", icon: "memorychip") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.bytes(stats.memory.usedBytes))
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                        Text("of \(Fmt.bytes(stats.memory.totalBytes))")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    AreaSpark(values: stats.history.memoryPercent.values(for: range), max: 100, color: .green, height: 160)
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
                if stats.memory.swapTotalBytes > 0 || stats.memory.swapUsedBytes > 0 {
                    MetricCard(title: "Swap", icon: "arrow.triangle.2.circlepath") {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Fmt.bytes(stats.memory.swapUsedBytes))
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                            if stats.memory.swapTotalBytes > 0 {
                                Text("of \(Fmt.bytes(stats.memory.swapTotalBytes))")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if stats.memory.swapTotalBytes > 0 {
                            ProgressView(
                                value: Double(stats.memory.swapUsedBytes),
                                total: Double(max(stats.memory.swapTotalBytes, 1))
                            )
                        }
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Swap in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(Fmt.rate(stats.memory.swapInsPerSec))
                                    .font(.callout)
                                    .monospacedDigit()
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Swap out")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(Fmt.rate(stats.memory.swapOutsPerSec))
                                    .font(.callout)
                                    .monospacedDigit()
                            }
                            Spacer()
                        }
                    }
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
    @State private var range: HistoryRange = .minute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(
                    title: "Disk",
                    subtitle: "History range: \(range.label)",
                    trailing: AnyView(HistoryRangePicker(selection: $range))
                )
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
                        inValues: stats.history.diskRead.values(for: range),
                        outValues: stats.history.diskWrite.values(for: range),
                        max: ScaleHelper.niceMax(
                            stats.history.diskRead.values(for: range) + stats.history.diskWrite.values(for: range),
                            minimum: 256 * 1024
                        ),
                        inColor: .purple,
                        outColor: .pink,
                        height: 160
                    )
                }
                if !stats.disk.volumes.isEmpty {
                    MetricCard(title: "Volumes (\(stats.disk.volumes.count))", icon: "externaldrive") {
                        VStack(spacing: 12) {
                            ForEach(stats.disk.volumes) { vol in
                                VolumeRow(volume: vol)
                                if vol.id != stats.disk.volumes.last?.id {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                    }
                } else if stats.disk.capacityBytes > 0 {
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
    @State private var range: HistoryRange = .minute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(
                    title: "Network",
                    subtitle: "History range: \(range.label)",
                    trailing: AnyView(HistoryRangePicker(selection: $range))
                )
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
                        inValues: stats.history.networkIn.values(for: range),
                        outValues: stats.history.networkOut.values(for: range),
                        max: ScaleHelper.niceMax(
                            stats.history.networkIn.values(for: range) + stats.history.networkOut.values(for: range),
                            minimum: 64 * 1024
                        ),
                        height: 160
                    )
                }
                if stats.wifi.isEnabled {
                    MetricCard(title: "Wi-Fi", icon: "wifi") {
                        WiFiInfoView(info: stats.wifi)
                    }
                }
                if !stats.network.interfaces.isEmpty {
                    MetricCard(title: "Interfaces (\(stats.network.interfaces.count))", icon: "network") {
                        VStack(spacing: 10) {
                            ForEach(stats.network.interfaces) { iface in
                                InterfaceRow(iface: iface)
                                if iface.id != stats.network.interfaces.last?.id {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                    }
                }
                MetricCard(title: "Session Totals", icon: "sum") {
                    StatRow(label: "Total in", value: Fmt.bytes(stats.network.totalIn))
                    StatRow(label: "Total out", value: Fmt.bytes(stats.network.totalOut))
                    if let pip = stats.publicIP {
                        StatRow(label: "Public IP", value: pip)
                    }
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
        .onAppear { stats.retainNetworkProcessSampling() }
        .onDisappear { stats.releaseNetworkProcessSampling() }
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
                if hasHistory {
                    MetricCard(title: "Charge History (last 30 min)", icon: "chart.xyaxis.line") {
                        AreaSpark(
                            values: stats.history.batteryPercent,
                            max: 100,
                            color: stats.battery.isCharging ? .green : .blue,
                            height: 120
                        )
                    }
                    MetricCard(title: "Power History (last 30 min)", icon: "bolt") {
                        CenteredSpark(
                            values: stats.history.batteryWattage,
                            color: .orange,
                            height: 100
                        )
                        Text(powerHistoryCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    if let w = stats.battery.wattage {
                        StatRow(label: "Power", value: Fmt.watts(w))
                    }
                }
                if hasHealthData {
                    MetricCard(title: "Health", icon: "heart.text.square") {
                        if let cycles = stats.battery.cycleCount {
                            StatRow(label: "Cycle count", value: "\(cycles)")
                        }
                        if let h = stats.battery.healthPercent {
                            StatRow(label: "Maximum capacity", value: Fmt.percent(h))
                        }
                        if let cur = stats.battery.currentMaxCapacityMAh {
                            StatRow(label: "Full charge", value: Fmt.milliAmpHours(cur))
                        }
                        if let design = stats.battery.designCapacityMAh {
                            StatRow(label: "Design capacity", value: Fmt.milliAmpHours(design))
                        }
                    }
                }
                if hasCellData {
                    MetricCard(title: "Cell", icon: "bolt") {
                        if let v = stats.battery.voltageVolts {
                            StatRow(label: "Voltage", value: Fmt.volts(v))
                        }
                        if let ma = stats.battery.amperageMilliAmps {
                            StatRow(label: "Current", value: Fmt.milliAmps(ma))
                        }
                        if let t = stats.battery.temperatureCelsius {
                            StatRow(label: "Temperature", value: Fmt.celsius(t))
                        }
                    }
                }
                if stats.battery.deviceName != nil || stats.battery.serial != nil {
                    MetricCard(title: "Hardware", icon: "cpu") {
                        if let name = stats.battery.deviceName {
                            StatRow(label: "Device", value: name)
                        }
                        if let s = stats.battery.serial {
                            StatRow(label: "Serial", value: s)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var hasHistory: Bool {
        stats.history.batteryPercent.contains(where: { $0 > 0 })
    }

    private var powerHistoryCaption: String {
        let vals = stats.history.batteryWattage.filter { $0 != 0 }
        guard !vals.isEmpty else { return "No power samples yet" }
        let avg = vals.reduce(0, +) / Double(vals.count)
        let label = avg >= 0 ? "Avg charge" : "Avg drain"
        return "\(label) \(String(format: "%.2f W", abs(avg)))"
    }

    private var hasHealthData: Bool {
        stats.battery.cycleCount != nil
            || stats.battery.healthPercent != nil
            || stats.battery.designCapacityMAh != nil
            || stats.battery.currentMaxCapacityMAh != nil
    }

    private var hasCellData: Bool {
        stats.battery.voltageVolts != nil
            || stats.battery.amperageMilliAmps != nil
            || stats.battery.temperatureCelsius != nil
    }

    private var status: String {
        if !stats.battery.hasBattery { return "No battery present" }
        if stats.battery.isCharging { return "Charging" }
        if stats.battery.isPluggedIn { return "Plugged in" }
        return "On battery"
    }
}

struct TemperaturePane: View {
    @ObservedObject var stats: SystemStats
    @State private var range: HistoryRange = .minute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(
                    title: "Temperature",
                    subtitle: subtitle,
                    trailing: AnyView(HistoryRangePicker(selection: $range))
                )
                MetricCard(title: "CPU", icon: "cpu") {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Self.format(stats.temperature.cpuCelsius))
                            .font(.system(size: 36, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Self.color(for: stats.temperature.cpuCelsius))
                        Spacer()
                        Text("Pressure: \(stats.thermal.label)")
                            .font(.caption)
                            .foregroundStyle(thermalColor)
                    }
                    AreaSpark(
                        values: stats.history.temperature.values(for: range),
                        max: ScaleHelper.niceMax(stats.history.temperature.values(for: range), minimum: 80),
                        color: .orange,
                        height: 160
                    )
                }
                HStack(spacing: 16) {
                    MetricCard(title: "GPU", icon: "display") {
                        Text(Self.format(stats.temperature.gpuCelsius))
                            .font(.system(size: 22, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Self.color(for: stats.temperature.gpuCelsius))
                    }
                    MetricCard(title: "Hottest sensor", icon: "thermometer.high") {
                        Text(Self.format(stats.temperature.maxCelsius))
                            .font(.system(size: 22, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Self.color(for: stats.temperature.maxCelsius))
                    }
                    MetricCard(title: "Sensors", icon: "dot.radiowaves.left.and.right") {
                        Text("\(stats.temperature.sensorCount)")
                            .font(.system(size: 22, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }
            .padding(24)
        }
    }

    private var subtitle: String {
        stats.temperature.hasReadings
            ? "Live thermal sensors via IOHID"
            : "No thermal sensors available"
    }

    private var thermalColor: Color {
        switch stats.thermal {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        case .unknown: return .secondary
        }
    }

    static func format(_ celsius: Double) -> String {
        if celsius <= 0 { return "--" }
        return String(format: "%.0f°C", celsius)
    }

    static func color(for celsius: Double) -> Color {
        if celsius <= 0 { return .secondary }
        if celsius >= 90 { return .red }
        if celsius >= 75 { return .orange }
        if celsius >= 60 { return .yellow }
        return .green
    }
}

struct WiFiInfoView: View {
    let info: WiFiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.ssid ?? (info.isConnected ? "Connected" : "Not connected"))
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                if info.isConnected {
                    SignalBars(qualityPercent: info.qualityPercent)
                    Text("\(info.rssi) dBm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if info.ssid == nil && info.isEnabled {
                Text("Grant Location permission to read SSID")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                if let ch = info.channel {
                    GridRow {
                        Text("Channel").foregroundStyle(.secondary)
                        Text(channelText(channel: ch, band: info.bandGHz, width: info.channelWidthMHz))
                            .monospacedDigit()
                    }
                }
                if info.txRateMbps > 0 {
                    GridRow {
                        Text("Tx rate").foregroundStyle(.secondary)
                        Text(String(format: "%.0f Mbps", info.txRateMbps)).monospacedDigit()
                    }
                }
                if let bssid = info.bssid {
                    GridRow {
                        Text("BSSID").foregroundStyle(.secondary)
                        Text(bssid).monospacedDigit().font(.caption)
                    }
                }
                if let mac = info.hardwareAddress {
                    GridRow {
                        Text("MAC").foregroundStyle(.secondary)
                        Text(mac).monospacedDigit().font(.caption)
                    }
                }
            }
            .font(.callout)
        }
    }

    private func channelText(channel: Int, band: Double?, width: Int?) -> String {
        var parts = ["#\(channel)"]
        if let band {
            parts.append(String(format: "%.1f GHz", band))
        }
        if let width {
            parts.append("\(width) MHz")
        }
        return parts.joined(separator: " · ")
    }
}

struct SignalBars: View {
    let qualityPercent: Double

    var body: some View {
        let active = max(0, min(4, Int((qualityPercent / 25).rounded())))
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < active ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(6 + i * 3))
            }
        }
    }
}

struct InterfaceRow: View {
    let iface: InterfaceStats

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: iface.isUp ? "circle.fill" : "circle")
                .font(.system(size: 7))
                .foregroundStyle(iface.isUp ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(iface.displayName)
                        .font(.callout.weight(.medium))
                    Text(iface.name)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                if iface.ipv4 != nil || iface.ipv6 != nil {
                    HStack(spacing: 8) {
                        if let v4 = iface.ipv4 {
                            Text(v4).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        if let v6 = iface.ipv6 {
                            Text(v6).font(.caption2).monospacedDigit().foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").font(.caption2).foregroundStyle(.blue)
                    Text(Fmt.rate(iface.bytesInPerSec)).font(.caption).monospacedDigit()
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up").font(.caption2).foregroundStyle(.orange)
                    Text(Fmt.rate(iface.bytesOutPerSec)).font(.caption).monospacedDigit()
                }
            }
        }
    }
}

struct VolumeRow: View {
    let volume: VolumeInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: volume.isInternal ? "internaldrive" : "externaldrive")
                    .foregroundStyle(.secondary)
                Text(volume.displayName)
                    .font(.callout.weight(.medium))
                Text(volume.bsdName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                if volume.isReadOnly {
                    Text("read-only")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.18)))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                smartBadge
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Fmt.bytes(volume.usedBytes)) / \(Fmt.bytes(volume.totalBytes))")
                    .font(.callout)
                    .monospacedDigit()
                Text("· \(Fmt.bytes(volume.freeBytes)) free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(Fmt.percent(volume.usagePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(
                value: Double(volume.usedBytes),
                total: Double(max(volume.totalBytes, 1))
            )
            Text(volume.mountPath)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var smartBadge: some View {
        let (text, color): (String, Color) = {
            switch volume.smartStatus {
            case .healthy:     return ("SMART OK", .green)
            case .failing:     return ("SMART FAIL", .red)
            case .unsupported: return ("SMART N/A", .secondary)
            case .unknown:     return ("SMART ?", .secondary)
            }
        }()
        return Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

struct CoreBars: View {
    let cores: [CoreUsage]
    let height: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(cores, id: \.coreId) { core in
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CoreBars.color(core.cluster).opacity(0.15))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(CoreBars.color(core.cluster))
                                .frame(height: max(2, geo.size.height * core.usage / 100))
                        }
                    }
                    .frame(height: height)
                    Text("\(core.coreId)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    static func color(_ cluster: CoreCluster) -> Color {
        switch cluster {
        case .performance: return .blue
        case .efficiency: return .green
        case .unified: return .accentColor
        }
    }
}

struct CoreLegend: View {
    let cores: [CoreUsage]

    var body: some View {
        let perfCount = cores.filter { $0.cluster == .performance }.count
        let effCount = cores.filter { $0.cluster == .efficiency }.count
        let unifiedCount = cores.filter { $0.cluster == .unified }.count
        HStack(spacing: 12) {
            if perfCount > 0 {
                LegendDot(color: .blue, label: "P-cores (\(perfCount))")
            }
            if effCount > 0 {
                LegendDot(color: .green, label: "E-cores (\(effCount))")
            }
            if unifiedCount > 0 {
                LegendDot(color: .accentColor, label: "Cores (\(unifiedCount))")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }
}

struct LoadAvgStat: View {
    let label: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f", value))
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
        }
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
