import Foundation
import Darwin

final class NetworkMonitor {
    struct Sample {
        var bytesInPerSec: Double
        var bytesOutPerSec: Double
        var totalIn: UInt64
        var totalOut: UInt64
    }

    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastTimestamp: Date?

    func sample() -> Sample {
        let (totalIn, totalOut) = readCounters()
        let now = Date()
        defer {
            lastIn = totalIn
            lastOut = totalOut
            lastTimestamp = now
        }
        guard let last = lastTimestamp else {
            return Sample(bytesInPerSec: 0, bytesOutPerSec: 0, totalIn: totalIn, totalOut: totalOut)
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0 else {
            return Sample(bytesInPerSec: 0, bytesOutPerSec: 0, totalIn: totalIn, totalOut: totalOut)
        }
        let inRate = Double(totalIn &- lastIn) / dt
        let outRate = Double(totalOut &- lastOut) / dt
        return Sample(bytesInPerSec: inRate, bytesOutPerSec: outRate, totalIn: totalIn, totalOut: totalOut)
    }

    private func readCounters() -> (UInt64, UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            let name = String(cString: cur.pointee.ifa_name)
            if name.hasPrefix("lo") { continue }
            guard let data = cur.pointee.ifa_data else { continue }
            guard cur.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            totalIn &+= UInt64(networkData.ifi_ibytes)
            totalOut &+= UInt64(networkData.ifi_obytes)
        }
        return (totalIn, totalOut)
    }
}
