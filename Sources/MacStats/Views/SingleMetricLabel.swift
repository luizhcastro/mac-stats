import SwiftUI
import AppKit

struct SingleMetricLabel: View {
    @ObservedObject var stats: SystemStats
    let metric: BarMetric

    private static let valueFont = Font.system(size: 9, weight: .bold).monospacedDigit()
    private static let iconFont = Font.system(size: 9, weight: .semibold)

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: metric.icon)
                .font(Self.iconFont)
            Text(text)
                .font(Self.valueFont)
                .lineLimit(1)
                .frame(width: width, alignment: .center)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var text: String {
        switch metric {
        case .cpu:
            let v = Int(stats.cpu.usage.rounded())
            return String(format: "%d%%", min(max(v, 0), 100))
        case .ram:
            let gb = Double(stats.memory.usedBytes) / 1_073_741_824.0
            if gb < 10 {
                return String(format: "%.1fG", gb)
            }
            return String(format: "%dG", Int(gb.rounded()))
        case .disk:
            return Self.compactShort(stats.disk.readPerSec + stats.disk.writePerSec)
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
        return String(format: "%.1fG", bps / 1024 / 1024 / 1024)
    }

    private var width: CGFloat {
        switch metric {
        case .cpu: return 26
        case .ram: return 26
        case .disk: return 28
        }
    }
}
