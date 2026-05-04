import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private let stats: SystemStats
    private var window: NSWindow?
    private var detailRetained = false

    init(stats: SystemStats) {
        self.stats = stats
    }

    func show() {
        if let window {
            activate(window)
            return
        }
        let window = makeWindow()
        self.window = window
        activate(window)
    }

    private func activate(_ window: NSWindow) {
        if !detailRetained {
            stats.retainDetailSampling()
            stats.retainFullProcessList()
            detailRetained = true
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = MainWindowView(stats: stats)
            .frame(minWidth: 760, minHeight: 480)
        let host = NSHostingController(rootView: content)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacStats"
        window.contentViewController = host
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("MacStatsMainWindow")
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        if detailRetained {
            stats.releaseDetailSampling()
            stats.releaseFullProcessList()
            detailRetained = false
        }
        NSApp.setActivationPolicy(.accessory)
    }
}
