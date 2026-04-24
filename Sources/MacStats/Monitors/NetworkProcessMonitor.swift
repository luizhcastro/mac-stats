import Foundation

@MainActor
final class NetworkProcessMonitor: ObservableObject {
    struct ProcStat: Identifiable {
        let id: String
        let name: String
        let pid: Int32
        var bytesInPerSec: Double
        var bytesOutPerSec: Double
    }

    @Published var processes: [ProcStat] = []
    private var isRunning = false

    func trigger() {
        guard !isRunning else { return }
        isRunning = true
        Task.detached { [weak self] in
            let results = Self.runNettop()
            await MainActor.run {
                self?.processes = results
                self?.isRunning = false
            }
        }
    }

    nonisolated static func runNettop() -> [ProcStat] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-L", "2", "-s", "1", "-d", "-x", "-J", "bytes_in,bytes_out", "-n"]
        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return parse(output)
    }

    nonisolated static func parse(_ output: String) -> [ProcStat] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        var headerCount = 0
        var secondSampleStart = -1
        for (i, line) in lines.enumerated() {
            if line.hasPrefix(",bytes_in,bytes_out") {
                headerCount += 1
                if headerCount == 2 {
                    secondSampleStart = i + 1
                    break
                }
            }
        }
        guard secondSampleStart >= 0 else { return [] }

        var results: [ProcStat] = []
        for line in lines[secondSampleStart...] {
            if line.hasPrefix(",bytes_in,bytes_out") { break }
            let parts = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { continue }
            let procField = parts[0]
            guard !procField.isEmpty else { continue }
            guard let bIn = Double(parts[1]), let bOut = Double(parts[2]) else { continue }
            guard let dotIdx = procField.lastIndex(of: ".") else { continue }
            let name = String(procField[..<dotIdx])
            let pidStr = String(procField[procField.index(after: dotIdx)...])
            guard let pid = Int32(pidStr) else { continue }
            results.append(ProcStat(
                id: "\(pid)",
                name: name,
                pid: pid,
                bytesInPerSec: bIn,
                bytesOutPerSec: bOut
            ))
        }
        return results
    }
}
