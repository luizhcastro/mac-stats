import AppKit
import Darwin

@MainActor
enum ProcessKill {
    enum Mode {
        case quit
        case forceKill

        var signal: Int32 { self == .forceKill ? SIGKILL : SIGTERM }
        var verb: String { self == .forceKill ? "Force Kill" : "Quit" }
    }

    static func confirmAndKill(pid: Int32, name: String, mode: Mode) {
        let alert = NSAlert()
        alert.messageText = "\(mode.verb) \(name)?"
        alert.informativeText = mode == .forceKill
            ? "Sends SIGKILL to PID \(pid). Unsaved work will be lost."
            : "Sends SIGTERM to PID \(pid)."
        alert.alertStyle = mode == .forceKill ? .warning : .informational
        alert.addButton(withTitle: mode.verb)
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let result = kill(pid, mode.signal)
        if result != 0 {
            let err = String(cString: strerror(errno))
            let fail = NSAlert()
            fail.messageText = "Failed to \(mode.verb.lowercased()) \(name)"
            fail.informativeText = "Error: \(err). Root-owned processes require admin privileges."
            fail.alertStyle = .critical
            fail.addButton(withTitle: "OK")
            fail.runModal()
        }
    }
}
