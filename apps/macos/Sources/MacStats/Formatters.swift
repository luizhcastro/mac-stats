import Foundation

enum Fmt {
    nonisolated(unsafe) private static let byteFormatter: ByteCountFormatter = {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        bcf.countStyle = .memory
        // Keeps live values at a constant width ("11.20 GB", not "11.2 GB" then "11.14 GB")
        bcf.zeroPadsFractionDigits = true
        return bcf
    }()

    nonisolated(unsafe) private static let totalFormatter: ByteCountFormatter = {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        bcf.countStyle = .memory
        return bcf
    }()

    static func bytes(_ value: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(value))
    }

    /// Fixed capacities ("16 GB", "494.38 GB"): no zero padding since they never change
    static func totalBytes(_ value: UInt64) -> String {
        totalFormatter.string(fromByteCount: Int64(value))
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

    /// "3d 4h", "4h 12m", "12m"
    static func uptime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        if m >= 24 * 60 { return "\(m / 1440)d \(m % 1440 / 60)h" }
        return minutes(m)
    }

    static func volts(_ v: Double) -> String {
        String(format: "%.2f V", v)
    }

    static func milliAmps(_ ma: Int) -> String {
        let sign = ma > 0 ? "+" : ""
        return "\(sign)\(ma) mA"
    }

    static func watts(_ w: Double) -> String {
        String(format: "%.2f W", w)
    }

    static func milliAmpHours(_ mAh: Int) -> String {
        "\(mAh) mAh"
    }

    static func celsius(_ c: Double) -> String {
        String(format: "%.1f°C", c)
    }
}
