import Foundation
import Darwin

final class NetworkProcessMonitor: @unchecked Sendable {
    struct ProcStat: Identifiable, Sendable {
        let id: Int32
        let name: String
        var bytesInPerSec: Double
        var bytesOutPerSec: Double
    }

    private struct Prior {
        var bytesIn: UInt64
        var bytesOut: UInt64
        var name: String
        var tick: UInt64
    }

    private struct PendingEntry {
        var stat: ProcStat
        var total: Double
    }

    private static let topK = 8
    private static let snapshotIntervalSeconds: Double = 3
    private static let invSnapshotInterval: Double = 1.0 / 3.0
    private static let bufferCompactThreshold = 4096

    private let lock = NSLock()
    private var _latest: [ProcStat] = []

    private var task: Process?
    private var masterHandle: FileHandle?

    private var buffer: [UInt8] = []
    private var bufHead = 0
    private var prior: [Int32: Prior] = [:]
    private var pending: [PendingEntry] = []
    private var staleScratch: [Int32] = []
    private var commaIdx: [Int] = [0, 0, 0, 0]
    private var pendingTick: UInt64 = 0
    private var seenFirstHeader = false

    func start() {
        guard task == nil else { return }

        buffer.removeAll(keepingCapacity: true)
        bufHead = 0
        prior.removeAll(keepingCapacity: true)
        pending.removeAll(keepingCapacity: true)
        staleScratch.removeAll(keepingCapacity: true)
        pendingTick = 0
        seenFirstHeader = false

        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else { return }

        let masterFH = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let slaveFH = FileHandle(fileDescriptor: slave, closeOnDealloc: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-x", "-J", "bytes_in,bytes_out", "-s", "3", "-n", "-L", "0"]
        process.standardInput = slaveFH
        process.standardOutput = slaveFH
        process.standardError = FileHandle.nullDevice

        masterFH.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            self?.handleChunk(chunk)
        }

        do {
            try process.run()
            self.task = process
            self.masterHandle = masterFH
        } catch {
            masterFH.readabilityHandler = nil
            try? masterFH.close()
            try? slaveFH.close()
        }
    }

    func stop() {
        masterHandle?.readabilityHandler = nil
        let dyingTask = task
        task = nil
        masterHandle?.closeFile()
        masterHandle = nil
        publish([])

        guard let dyingTask else { return }
        dyingTask.terminate()
        let pid = dyingTask.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
            if dyingTask.isRunning {
                _ = Darwin.kill(pid, SIGKILL)
            }
        }
    }

    func sample() -> [ProcStat] {
        lock.lock()
        defer { lock.unlock() }
        return _latest
    }

    private func publish(_ snapshot: [ProcStat]) {
        lock.lock()
        _latest = snapshot
        lock.unlock()
    }

    private func handleChunk(_ chunk: Data) {
        chunk.withUnsafeBytes { raw in
            if let base = raw.baseAddress, raw.count > 0 {
                let bp = UnsafeBufferPointer<UInt8>(
                    start: base.assumingMemoryBound(to: UInt8.self),
                    count: raw.count
                )
                buffer.append(contentsOf: bp)
            }
        }

        let count = buffer.count
        var lineStart = bufHead
        var i = bufHead
        while i < count {
            if buffer[i] == 0x0a {
                handleLine(start: lineStart, end: i)
                lineStart = i + 1
            }
            i += 1
        }
        bufHead = lineStart

        if bufHead >= Self.bufferCompactThreshold {
            buffer.removeFirst(bufHead)
            bufHead = 0
        }
    }

    private func handleLine(start: Int, end: Int) {
        var realEnd = end
        if realEnd > start && buffer[realEnd - 1] == 0x0d { realEnd -= 1 }
        let len = realEnd - start
        if len == 0 { return }

        // Header line: "time,…"
        if len >= 5
            && buffer[start] == 0x74
            && buffer[start &+ 1] == 0x69
            && buffer[start &+ 2] == 0x6d
            && buffer[start &+ 3] == 0x65
            && buffer[start &+ 4] == 0x2c {
            if seenFirstHeader {
                flushPending()
                sweepStalePrior()
            }
            seenFirstHeader = true
            pendingTick &+= 1
            return
        }

        // Skip rows with both counters zero — most idle daemons. Pattern ",0,0," at tail.
        if len >= 5
            && buffer[realEnd &- 1] == 0x2c
            && buffer[realEnd &- 2] == 0x30
            && buffer[realEnd &- 3] == 0x2c
            && buffer[realEnd &- 4] == 0x30
            && buffer[realEnd &- 5] == 0x2c {
            return
        }

        parseRow(start: start, end: realEnd)
    }

    private func parseRow(start: Int, end: Int) {
        var found = 0
        var i = start
        while i < end {
            if buffer[i] == 0x2c {
                commaIdx[found] = i
                found &+= 1
                if found == 4 { break }
            }
            i &+= 1
        }
        if found < 4 { return }

        let c0 = commaIdx[0]
        let c1 = commaIdx[1]
        let c2 = commaIdx[2]
        let c3 = commaIdx[3]

        // Find rightmost '.' in name field (pid suffix is short).
        var dotIdx = -1
        var j = c1 &- 1
        while j > c0 {
            if buffer[j] == 0x2e { dotIdx = j; break }
            j &-= 1
        }
        if dotIdx < 0 || dotIdx &+ 1 >= c1 { return }

        // Parse pid.
        var pid: Int32 = 0
        var k = dotIdx &+ 1
        while k < c1 {
            let b = buffer[k]
            if b < 0x30 || b > 0x39 { return }
            pid = pid &* 10 &+ Int32(b &- 0x30)
            k &+= 1
        }

        // Parse bytes_in.
        var bytesIn: UInt64 = 0
        k = c1 &+ 1
        while k < c2 {
            let b = buffer[k]
            if b < 0x30 || b > 0x39 { return }
            bytesIn = bytesIn &* 10 &+ UInt64(b &- 0x30)
            k &+= 1
        }

        // Parse bytes_out.
        var bytesOut: UInt64 = 0
        k = c2 &+ 1
        while k < c3 {
            let b = buffer[k]
            if b < 0x30 || b > 0x39 { return }
            bytesOut = bytesOut &* 10 &+ UInt64(b &- 0x30)
            k &+= 1
        }

        // Trim whitespace around name slice [c0+1, dotIdx).
        var ns = c0 &+ 1
        var ne = dotIdx
        while ns < ne {
            let b = buffer[ns]
            if b == 0x20 || b == 0x09 || b == 0x0d { ns &+= 1 } else { break }
        }
        while ne > ns {
            let b = buffer[ne &- 1]
            if b == 0x20 || b == 0x09 || b == 0x0d { ne &-= 1 } else { break }
        }

        // Hot path: existing prior + matching name → reuse name string, compute rate.
        if let p = prior[pid], byteEqualsString(p.name, start: ns, end: ne) {
            let inRate = bytesIn >= p.bytesIn
                ? Double(bytesIn &- p.bytesIn) * Self.invSnapshotInterval : 0
            let outRate = bytesOut >= p.bytesOut
                ? Double(bytesOut &- p.bytesOut) * Self.invSnapshotInterval : 0
            prior[pid] = Prior(bytesIn: bytesIn, bytesOut: bytesOut, name: p.name, tick: pendingTick)
            if inRate <= 0 && outRate <= 0 { return }
            insertPending(pid: pid, name: p.name, inRate: inRate, outRate: outRate)
            return
        }

        // New / recycled pid: store baseline. No rate this tick.
        let name: String
        if ne == ns {
            name = ""
        } else {
            name = String(decoding: buffer[ns..<ne], as: UTF8.self)
        }
        prior[pid] = Prior(bytesIn: bytesIn, bytesOut: bytesOut, name: name, tick: pendingTick)
    }

    private func insertPending(pid: Int32, name: String, inRate: Double, outRate: Double) {
        let total = inRate + outRate
        let limit = Self.topK
        if pending.count < limit {
            let displayName = name.isEmpty ? "pid:\(pid)" : name
            let stat = ProcStat(id: pid, name: displayName, bytesInPerSec: inRate, bytesOutPerSec: outRate)
            pending.append(PendingEntry(stat: stat, total: total))
            var i = pending.count &- 1
            while i > 0 && pending[i].total > pending[i &- 1].total {
                pending.swapAt(i, i &- 1)
                i &-= 1
            }
            return
        }
        let lastIdx = limit &- 1
        if total <= pending[lastIdx].total { return }
        let displayName = name.isEmpty ? "pid:\(pid)" : name
        let stat = ProcStat(id: pid, name: displayName, bytesInPerSec: inRate, bytesOutPerSec: outRate)
        pending[lastIdx] = PendingEntry(stat: stat, total: total)
        var i = lastIdx
        while i > 0 && pending[i].total > pending[i &- 1].total {
            pending.swapAt(i, i &- 1)
            i &-= 1
        }
    }

    private func flushPending() {
        if pending.isEmpty {
            publish([])
            return
        }
        var snap: [ProcStat] = []
        snap.reserveCapacity(pending.count)
        for e in pending { snap.append(e.stat) }
        publish(snap)
        pending.removeAll(keepingCapacity: true)
    }

    private func sweepStalePrior() {
        for (k, v) in prior where v.tick != pendingTick {
            staleScratch.append(k)
        }
        if staleScratch.isEmpty { return }
        for k in staleScratch { prior.removeValue(forKey: k) }
        staleScratch.removeAll(keepingCapacity: true)
    }

    private func byteEqualsString(_ s: String, start: Int, end: Int) -> Bool {
        let len = end - start
        let utf8 = s.utf8
        if utf8.count != len { return false }
        var i = start
        for u in utf8 {
            if buffer[i] != u { return false }
            i &+= 1
        }
        return true
    }
}
