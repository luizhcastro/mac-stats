import Foundation

struct FanInfo: Sendable, Identifiable {
    let id: Int
    let name: String
    let currentRPM: Int
    let minRPM: Int
    let maxRPM: Int
    let targetRPM: Int?

    var loadPercent: Double {
        guard maxRPM > minRPM else { return 0 }
        let span = Double(maxRPM - minRPM)
        let pos = max(0, min(span, Double(currentRPM - minRPM)))
        return pos / span * 100
    }
}

final class FanMonitor {
    struct Sample: Sendable {
        var fans: [FanInfo]
        var hasReadings: Bool
        var supported: Bool

        static let empty = Sample(fans: [], hasReadings: false, supported: false)
    }

    private let smc = SMCClient()

    func sample() -> Sample {
        guard smc.isOpen else { return .empty }
        guard let countValue = smc.readKey("FNum"),
              let countDouble = countValue.asDouble() else {
            return Sample(fans: [], hasReadings: false, supported: true)
        }
        let count = Int(countDouble)
        guard count > 0 else {
            return Sample(fans: [], hasReadings: false, supported: true)
        }

        var fans: [FanInfo] = []
        fans.reserveCapacity(count)
        for i in 0..<count {
            let cur = smc.readKey("F\(i)Ac")?.asDouble() ?? 0
            let mn = smc.readKey("F\(i)Mn")?.asDouble() ?? 0
            let mx = smc.readKey("F\(i)Mx")?.asDouble() ?? 0
            let target = smc.readKey("F\(i)Tg")?.asDouble().map { Int($0) }
            let name = smc.readKey("F\(i)ID").flatMap { Self.decodeFanID($0.bytes) }
                ?? "Fan \(i + 1)"
            fans.append(FanInfo(
                id: i,
                name: name,
                currentRPM: Int(cur),
                minRPM: Int(mn),
                maxRPM: Int(mx),
                targetRPM: target
            ))
        }
        let any = fans.contains(where: { $0.currentRPM > 0 || $0.maxRPM > 0 })
        return Sample(fans: fans, hasReadings: any, supported: true)
    }

    private static func decodeFanID(_ bytes: [UInt8]) -> String? {
        guard bytes.count > 4 else { return nil }
        let nameBytes = bytes.dropFirst(4).prefix { $0 != 0 }
        let s = String(decoding: Array(nameBytes), as: UTF8.self).trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}
