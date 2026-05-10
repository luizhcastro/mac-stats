import Foundation
import Darwin

struct InterfaceStats: Sendable, Identifiable {
    var name: String
    var displayName: String
    var ipv4: String?
    var ipv6: String?
    var bytesInPerSec: Double
    var bytesOutPerSec: Double
    var totalIn: UInt64
    var totalOut: UInt64
    var isUp: Bool
    var isLoopback: Bool

    var id: String { name }
}

final class NetworkMonitor {
    struct Sample: Sendable {
        var bytesInPerSec: Double
        var bytesOutPerSec: Double
        var totalIn: UInt64
        var totalOut: UInt64
        var interfaces: [InterfaceStats]
    }

    private struct PerIface {
        var totalIn: UInt64
        var totalOut: UInt64
        var at: Date
    }

    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastTimestamp: Date?
    private var lastPerIface: [String: PerIface] = [:]

    func sample(includeInterfaceDetail: Bool = false) -> Sample {
        let now = Date()
        let snapshot = readCounters(at: now, includeAddresses: includeInterfaceDetail)

        let aggIn = snapshot.aggregateIn
        let aggOut = snapshot.aggregateOut

        var inRate: Double = 0
        var outRate: Double = 0
        if let last = lastTimestamp {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                inRate = SamplingMath.rate(current: aggIn, previous: lastIn, dt: dt)
                outRate = SamplingMath.rate(current: aggOut, previous: lastOut, dt: dt)
            }
        }

        var interfaces: [InterfaceStats] = []
        if includeInterfaceDetail {
            interfaces.reserveCapacity(snapshot.ifaces.count)
            var nextPerIface: [String: PerIface] = [:]
            nextPerIface.reserveCapacity(snapshot.ifaces.count)

            for raw in snapshot.ifaces {
                let prev = lastPerIface[raw.name]
                var bps = (in: 0.0, out: 0.0)
                if let prev {
                    let dt = now.timeIntervalSince(prev.at)
                    if dt > 0 {
                        bps.in = SamplingMath.rate(current: raw.bytesIn, previous: prev.totalIn, dt: dt)
                        bps.out = SamplingMath.rate(current: raw.bytesOut, previous: prev.totalOut, dt: dt)
                    }
                }
                nextPerIface[raw.name] = PerIface(totalIn: raw.bytesIn, totalOut: raw.bytesOut, at: now)
                if raw.isLoopback { continue }
                interfaces.append(InterfaceStats(
                    name: raw.name,
                    displayName: Self.displayName(for: raw.name),
                    ipv4: raw.ipv4,
                    ipv6: raw.ipv6,
                    bytesInPerSec: bps.in,
                    bytesOutPerSec: bps.out,
                    totalIn: raw.bytesIn,
                    totalOut: raw.bytesOut,
                    isUp: raw.isUp,
                    isLoopback: false
                ))
            }
            interfaces.sort { lhs, rhs in
                if lhs.isUp != rhs.isUp { return lhs.isUp }
                let lhsActive = (lhs.bytesInPerSec + lhs.bytesOutPerSec) > 0
                let rhsActive = (rhs.bytesInPerSec + rhs.bytesOutPerSec) > 0
                if lhsActive != rhsActive { return lhsActive }
                return lhs.name < rhs.name
            }
            lastPerIface = nextPerIface
        } else {
            lastPerIface = [:]
        }

        defer {
            lastIn = aggIn
            lastOut = aggOut
            lastTimestamp = now
        }

        return Sample(
            bytesInPerSec: inRate,
            bytesOutPerSec: outRate,
            totalIn: aggIn,
            totalOut: aggOut,
            interfaces: interfaces
        )
    }

    private struct RawInterface {
        var name: String
        var bytesIn: UInt64
        var bytesOut: UInt64
        var ipv4: String?
        var ipv6: String?
        var isUp: Bool
        var isLoopback: Bool
    }

    private struct RawSnapshot {
        var ifaces: [RawInterface]
        var aggregateIn: UInt64
        var aggregateOut: UInt64
    }

    private func readCounters(at now: Date, includeAddresses: Bool) -> RawSnapshot {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return RawSnapshot(ifaces: [], aggregateIn: 0, aggregateOut: 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var byName: [String: RawInterface] = [:]
        var aggIn: UInt64 = 0
        var aggOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let namePtr = cur.pointee.ifa_name else { continue }
            let name = String(cString: namePtr)
            let isLoopback = name.hasPrefix("lo")
            let flags = Int32(cur.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0

            var entry = byName[name] ?? RawInterface(
                name: name, bytesIn: 0, bytesOut: 0,
                ipv4: nil, ipv6: nil,
                isUp: isUp, isLoopback: isLoopback
            )
            entry.isUp = isUp

            guard let sa = cur.pointee.ifa_addr else {
                byName[name] = entry
                continue
            }
            let family = sa.pointee.sa_family

            switch Int32(family) {
            case AF_LINK:
                if let data = cur.pointee.ifa_data {
                    let nd = data.assumingMemoryBound(to: if_data.self).pointee
                    entry.bytesIn = UInt64(nd.ifi_ibytes)
                    entry.bytesOut = UInt64(nd.ifi_obytes)
                    if !isLoopback {
                        aggIn &+= entry.bytesIn
                        aggOut &+= entry.bytesOut
                    }
                }
            case AF_INET:
                if includeAddresses {
                    entry.ipv4 = Self.formatAddr(sa, family: AF_INET)
                }
            case AF_INET6:
                if includeAddresses, entry.ipv6 == nil,
                   let s = Self.formatAddr(sa, family: AF_INET6), !s.hasPrefix("fe80") {
                    entry.ipv6 = s
                }
            default:
                break
            }
            byName[name] = entry
        }

        return RawSnapshot(ifaces: Array(byName.values), aggregateIn: aggIn, aggregateOut: aggOut)
    }

    private static func formatAddr(_ sa: UnsafePointer<sockaddr>, family: Int32) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let salen: socklen_t
        switch family {
        case AF_INET:  salen = socklen_t(MemoryLayout<sockaddr_in>.size)
        case AF_INET6: salen = socklen_t(MemoryLayout<sockaddr_in6>.size)
        default: return nil
        }
        let result = getnameinfo(
            sa, salen,
            &host, socklen_t(host.count),
            nil, 0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func displayName(for ifname: String) -> String {
        if ifname == "en0" { return "Wi-Fi / Ethernet" }
        if ifname.hasPrefix("en") { return "Ethernet (\(ifname))" }
        if ifname.hasPrefix("utun") { return "VPN (\(ifname))" }
        if ifname.hasPrefix("awdl") { return "AirDrop" }
        if ifname.hasPrefix("llw") { return "Low-latency Wi-Fi" }
        if ifname.hasPrefix("bridge") { return "Bridge (\(ifname))" }
        if ifname.hasPrefix("anpi") { return "Apple NPCI" }
        if ifname.hasPrefix("ap") { return "Access Point" }
        if ifname.hasPrefix("gif") || ifname.hasPrefix("stf") { return "Tunnel (\(ifname))" }
        return ifname
    }
}
