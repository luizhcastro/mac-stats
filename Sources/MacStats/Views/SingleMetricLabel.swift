import SwiftUI
import AppKit

struct SingleMetricLabel: View {
    @ObservedObject var stats: SystemStats
    let metric: BarMetric

    var body: some View {
        if metric == .appIcon {
            AppIconLabel()
        } else {
            SingleMetricLabelContent(text: text, icon: metric.icon, width: width)
                .equatable()
        }
    }

    private var text: String {
        switch metric {
        case .cpu:
            let v = Int(stats.cpu.usage.rounded())
            return String(format: "%d%%", min(max(v, 0), 100))
        case .temperature:
            let t = stats.temperature.cpuCelsius > 0
                ? stats.temperature.cpuCelsius
                : stats.temperature.maxCelsius
            if t > 0 { return String(format: "%d°", Int(t.rounded())) }
            return "--°"
        case .ram:
            let gb = Double(stats.memory.usedBytes) / 1_073_741_824.0
            if gb < 10 {
                return String(format: "%.1fG", gb)
            }
            return String(format: "%dG", Int(gb.rounded()))
        case .disk:
            return Self.compactShort(stats.disk.readPerSec + stats.disk.writePerSec)
        case .network:
            return Self.compactShort(stats.network.bytesInPerSec + stats.network.bytesOutPerSec)
        case .appIcon:
            return ""
        }
    }

    private static func compactShort(_ bps: Double) -> String {
        if bps < 1024 { return "0K" }
        if bps < 1024 * 1024 {
            return String(format: "%.0fK", bps / 1024)
        }
        if bps < 1024 * 1024 * 1024 {
            let mb = bps / 1024 / 1024
            if mb < 10 { return String(format: "%.1fM", mb) }
            return String(format: "%dM", Int(mb.rounded()))
        }
        let gb = bps / 1024 / 1024 / 1024
        if gb < 10 { return String(format: "%.1fG", gb) }
        return String(format: "%dG", Int(gb.rounded()))
    }

    private var width: CGFloat {
        switch metric {
        case .cpu: return 30
        case .temperature: return 26
        case .ram: return 32
        case .disk: return 36
        case .network: return 36
        case .appIcon: return 18
        }
    }
}

private struct AppIconLabel: View {
    private static let icon = NSImage(named: "AppIcon")

    var body: some View {
        Group {
            if let icon = Self.icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "speedometer").resizable()
            }
        }
        .frame(width: 17, height: 17)
        .padding(.horizontal, 2)
    }
}

private struct SingleMetricLabelContent: View, Equatable {
    let text: String
    let icon: String
    let width: CGFloat

    private static let valueFont = Font.system(size: 9, weight: .bold).monospacedDigit()
    private static let iconFont = Font.system(size: 9, weight: .semibold)

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(Self.iconFont)
            Text(text)
                .font(Self.valueFont)
                .lineLimit(1)
                .frame(width: width, alignment: .center)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
