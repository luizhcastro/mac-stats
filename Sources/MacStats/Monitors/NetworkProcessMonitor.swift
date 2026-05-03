import Foundation

final class NetworkProcessMonitor {
    struct ProcStat: Identifiable, Sendable {
        let id: Int32
        let name: String
        var bytesInPerSec: Double
        var bytesOutPerSec: Double
    }

    private struct Prior {
        let name: String
        let bytesIn: UInt64
        let bytesOut: UInt64
        let timestamp: Date
    }

    private var prior: [Int32: Prior] = [:]

    func sample() -> [ProcStat] {
        guard let raw = runNettop() else { return [] }
        let now = Date()
        var nextPrior: [Int32: Prior] = [:]
        var results: [ProcStat] = []

        for line in raw.split(separator: "\n").dropFirst() {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 4 else { continue }
            let nameField = String(fields[1])
            guard let dotIdx = nameField.lastIndex(of: ".") else { continue }
            let pidStr = nameField[nameField.index(after: dotIdx)...]
            guard let pid = Int32(pidStr) else { continue }
            let rawName = String(nameField[..<dotIdx])
            let name = rawName.trimmingCharacters(in: .whitespaces)
            guard let bytesIn = UInt64(fields[2]), let bytesOut = UInt64(fields[3]) else { continue }

            var inRate = 0.0
            var outRate = 0.0
            if let p = prior[pid], p.name == name {
                let dt = now.timeIntervalSince(p.timestamp)
                if dt > 0 {
                    inRate = SamplingMath.rate(current: bytesIn, previous: p.bytesIn, dt: dt)
                    outRate = SamplingMath.rate(current: bytesOut, previous: p.bytesOut, dt: dt)
                }
            }

            nextPrior[pid] = Prior(name: name, bytesIn: bytesIn, bytesOut: bytesOut, timestamp: now)
            results.append(ProcStat(
                id: pid,
                name: name.isEmpty ? "pid:\(pid)" : name,
                bytesInPerSec: max(0, inRate),
                bytesOutPerSec: max(0, outRate)
            ))
        }

        prior = nextPrior
        return results
    }

    private func runNettop() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-x", "-J", "bytes_in,bytes_out", "-L", "1", "-n"]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        do {
            try task.run()
        } catch {
            return nil
        }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
