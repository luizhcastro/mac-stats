import Foundation

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

    private static let topK = 8
    private static let snapshotIntervalSeconds: Double = 2
    private static let timeMarker: [UInt8] = [0x74, 0x69, 0x6d, 0x65, 0x2c] // "time,"

    private let lock = NSLock()
    private var _latest: [ProcStat] = []

    private var task: Process?
    private var stdoutPipe: Pipe?

    private var buffer = Data()
    private var prior: [Int32: Prior] = [:]
    private var pending: [ProcStat] = []
    private var staleScratch: [Int32] = []
    private var pendingTick: UInt64 = 0
    private var seenFirstHeader = false

    func start() {
        guard task == nil else { return }

        buffer.removeAll(keepingCapacity: true)
        prior.removeAll(keepingCapacity: true)
        pending.removeAll(keepingCapacity: true)
        staleScratch.removeAll(keepingCapacity: true)
        pendingTick = 0
        seenFirstHeader = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-x", "-J", "bytes_in,bytes_out", "-s", "2", "-n", "-L", "0"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty { return }
            self?.handleChunk(chunk)
        }

        do {
            try process.run()
            self.task = process
            self.stdoutPipe = stdout
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
        }
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        task?.terminate()
        task = nil
        stdoutPipe = nil
        publish([])
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
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: 0x0a) {
            let lineRange = buffer.startIndex..<nl
            handleLine(buffer[lineRange])
            buffer.removeSubrange(buffer.startIndex...nl)
        }
    }

    private func handleLine(_ line: Data) {
        if line.starts(with: Self.timeMarker) {
            if seenFirstHeader {
                let topK = buildTopK(from: pending, limit: Self.topK)
                publish(topK)
                pending.removeAll(keepingCapacity: true)
                sweepStalePrior()
            }
            seenFirstHeader = true
            pendingTick &+= 1
            return
        }
        guard !line.isEmpty else { return }
        parseRow(line)
    }

    private func parseRow(_ line: Data) {
        var commas: [Data.Index] = []
        commas.reserveCapacity(4)
        for idx in line.indices where line[idx] == 0x2c {
            commas.append(idx)
            if commas.count == 4 { break }
        }
        guard commas.count >= 4 else { return }

        let nameField = line[line.index(after: commas[0])..<commas[1]]
        let bytesInField = line[line.index(after: commas[1])..<commas[2]]
        let bytesOutField = line[line.index(after: commas[2])..<commas[3]]

        var lastDot: Data.Index? = nil
        for idx in nameField.indices where nameField[idx] == 0x2e {
            lastDot = idx
        }
        guard let dotIdx = lastDot else { return }
        let pidStart = nameField.index(after: dotIdx)
        guard pidStart < nameField.endIndex else { return }
        guard let pid = parseInt32(nameField[pidStart..<nameField.endIndex]) else { return }
        guard let bytesIn = parseUInt64(bytesInField) else { return }
        guard let bytesOut = parseUInt64(bytesOutField) else { return }

        let nameSlice = trimWhitespace(nameField[nameField.startIndex..<dotIdx])
        let cachedName = prior[pid].flatMap { p in byteEquals(p.name, nameSlice) ? p.name : nil }
        let name: String
        if let cachedName {
            name = cachedName
        } else if nameSlice.isEmpty {
            name = ""
        } else {
            name = String(decoding: nameSlice, as: UTF8.self)
        }

        var inRate = 0.0
        var outRate = 0.0
        if let p = prior[pid], p.name == name {
            let dt = Self.snapshotIntervalSeconds
            inRate = SamplingMath.rate(current: bytesIn, previous: p.bytesIn, dt: dt)
            outRate = SamplingMath.rate(current: bytesOut, previous: p.bytesOut, dt: dt)
        }
        prior[pid] = Prior(bytesIn: bytesIn, bytesOut: bytesOut, name: name, tick: pendingTick)

        if inRate <= 0 && outRate <= 0 { return }

        let displayName = name.isEmpty ? "pid:\(pid)" : name
        let stat = ProcStat(
            id: pid,
            name: displayName,
            bytesInPerSec: max(0, inRate),
            bytesOutPerSec: max(0, outRate)
        )
        insertTopKBuffer(stat)
    }

    private func insertTopKBuffer(_ stat: ProcStat) {
        let limit = Self.topK
        let total = stat.bytesInPerSec + stat.bytesOutPerSec
        if pending.count < limit {
            pending.append(stat)
            var i = pending.count - 1
            while i > 0 && (pending[i].bytesInPerSec + pending[i].bytesOutPerSec) > (pending[i - 1].bytesInPerSec + pending[i - 1].bytesOutPerSec) {
                pending.swapAt(i, i - 1)
                i -= 1
            }
            return
        }
        let lastIdx = limit - 1
        let lastTotal = pending[lastIdx].bytesInPerSec + pending[lastIdx].bytesOutPerSec
        if total <= lastTotal { return }
        pending[lastIdx] = stat
        var i = lastIdx
        while i > 0 && (pending[i].bytesInPerSec + pending[i].bytesOutPerSec) > (pending[i - 1].bytesInPerSec + pending[i - 1].bytesOutPerSec) {
            pending.swapAt(i, i - 1)
            i -= 1
        }
    }

    private func buildTopK(from list: [ProcStat], limit: Int) -> [ProcStat] {
        list
    }

    private func sweepStalePrior() {
        staleScratch.removeAll(keepingCapacity: true)
        for (k, v) in prior where v.tick != pendingTick {
            staleScratch.append(k)
        }
        for k in staleScratch {
            prior.removeValue(forKey: k)
        }
    }

    private func parseInt32(_ slice: Data) -> Int32? {
        var n: Int32 = 0
        var any = false
        for b in slice {
            guard b >= 0x30 && b <= 0x39 else { return nil }
            n = n &* 10 &+ Int32(b - 0x30)
            any = true
        }
        return any ? n : nil
    }

    private func parseUInt64(_ slice: Data) -> UInt64? {
        var n: UInt64 = 0
        var any = false
        for b in slice {
            guard b >= 0x30 && b <= 0x39 else { return nil }
            n = n &* 10 &+ UInt64(b - 0x30)
            any = true
        }
        return any ? n : nil
    }

    private func trimWhitespace(_ slice: Data) -> Data {
        var start = slice.startIndex
        var end = slice.endIndex
        while start < end, isSpace(slice[start]) { start = slice.index(after: start) }
        while end > start, isSpace(slice[slice.index(before: end)]) { end = slice.index(before: end) }
        return slice[start..<end]
    }

    private func isSpace(_ b: UInt8) -> Bool {
        b == 0x20 || b == 0x09 || b == 0x0d
    }

    private func byteEquals(_ s: String, _ d: Data) -> Bool {
        let utf8 = s.utf8
        guard utf8.count == d.count else { return false }
        var di = d.startIndex
        for u in utf8 {
            if u != d[di] { return false }
            di = d.index(after: di)
        }
        return true
    }
}
