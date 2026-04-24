import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject var stats: SystemStats
    @ObservedObject var snapshot: MenuBarSnapshot

    private static let valueFont = Font.system(size: 10, weight: .bold).monospacedDigit()
    private static let iconFont = Font.system(size: 10, weight: .semibold)

    var body: some View {
        HStack(spacing: 9) {
            if snapshot.selected.contains(.cpu) { slot(icon: "cpu", text: cpuText, width: 26) }
            if snapshot.selected.contains(.ram) { slot(icon: "memorychip", text: ramText, width: 44) }
            if snapshot.selected.contains(.disk) { slot(icon: "internaldrive", text: diskText, width: 50) }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func slot(icon: String, text: String, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(Self.iconFont)
            Text(text)
                .font(Self.valueFont)
                .lineLimit(1)
                .frame(width: width, alignment: .center)
        }
    }

    private var cpuText: String {
        let v = Int(stats.cpu.usage.rounded())
        return String(format: "%d%%", min(max(v, 0), 99))
    }

    private var ramText: String {
        let gb = Double(stats.memory.usedBytes) / 1_073_741_824.0
        if gb < 10 {
            return String(format: "%.1fGB", gb)
        }
        return String(format: "%dGB", Int(gb.rounded()))
    }

    private var diskText: String {
        Fmt.compactRate(stats.disk.readPerSec + stats.disk.writePerSec)
    }
}
