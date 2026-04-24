import Foundation

enum Fmt {
    static func bytes(_ value: UInt64) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        bcf.countStyle = .memory
        return bcf.string(fromByteCount: Int64(value))
    }

    static func compactRate(_ bytesPerSec: Double) -> String {
        let v = bytesPerSec
        if v < 1024 { return "0 K/s" }
        if v < 1024 * 1024 { return String(format: "%.0f K/s", v / 1024) }
        if v < 1024 * 1024 * 1024 { return String(format: "%.1f M/s", v / 1024 / 1024) }
        return String(format: "%.1f G/s", v / 1024 / 1024 / 1024)
    }

    static func rate(_ bytesPerSec: Double) -> String {
        let v = bytesPerSec
        if v < 1024 { return String(format: "%.0f B/s", v) }
        if v < 1024 * 1024 { return String(format: "%.1f KB/s", v / 1024) }
        if v < 1024 * 1024 * 1024 { return String(format: "%.1f MB/s", v / 1024 / 1024) }
        return String(format: "%.2f GB/s", v / 1024 / 1024 / 1024)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func minutes(_ m: Int) -> String {
        let h = m / 60
        let r = m % 60
        if h > 0 { return "\(h)h \(r)m" }
        return "\(r)m"
    }
}
