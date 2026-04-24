import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var stats: SystemStats
    @ObservedObject var prefs: DisplayPreferences

    private let font = Font.system(size: 12, weight: .regular)

    var body: some View {
        HStack(spacing: 8) {
            if prefs.isSelected(.cpu) {
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                    Text(cpuText)
                        .font(font)
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
            }
            if prefs.isSelected(.ram) {
                HStack(spacing: 3) {
                    Image(systemName: "memorychip")
                    Text(ramText)
                        .font(font)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
            if prefs.isSelected(.disk) {
                HStack(spacing: 3) {
                    Image(systemName: "internaldrive")
                    Text(diskText)
                        .font(font)
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var cpuText: String {
        let v = Int(stats.cpu.usage.rounded())
        return "\(min(max(v, 0), 99))%"
    }

    private var ramText: String {
        let gb = Double(stats.memory.usedBytes) / 1_073_741_824.0
        if gb < 10 {
            return String(format: "%.1f GB", gb)
        }
        return String(format: "%.0f GB", gb)
    }

    private var diskText: String {
        Fmt.compactRate(stats.disk.readPerSec + stats.disk.writePerSec)
    }
}
