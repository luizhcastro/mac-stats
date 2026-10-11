import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private let stats: SystemStats
    private let prefs: DisplayPreferences
    private var window: NSWindow?
    private var detailRetained = false

    init(stats: SystemStats, prefs: DisplayPreferences) {
        self.stats = stats
        self.prefs = prefs
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
        setDetailRetained(true)
        prefs.applyActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = MainWindowView(stats: stats, prefs: prefs)
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
        if #available(macOS 26, *) {
            // See-through window: desktop shows behind the glass sidebar/cards.
            let glass = NSGlassEffectView()
            glass.cornerRadius = 0
            host.view.frame = glass.bounds
            glass.contentView = host.view
            window.contentView = glass
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("MacStatsMainWindow")
        window.delegate = self
        return window
    }

    private func setDetailRetained(_ retained: Bool) {
        guard retained != detailRetained else { return }
        detailRetained = retained
        if retained {
            stats.retainDetailSampling()
            stats.retainWindowDetail()
        } else {
            stats.releaseWindowDetail()
            stats.releaseDetailSampling()
        }
    }

    /// Minimized, on another Space or fully covered: stop the detail tier
    /// (and with it process / nettop sampling) until the window is visible.
    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window, notification.object as? NSWindow === window else { return }
        setDetailRetained(window.occlusionState.contains(.visible))
    }

    func windowWillClose(_ notification: Notification) {
        setDetailRetained(false)
        prefs.applyActivationPolicy()
        // The window is retained (isReleasedWhenClosed = false), so its SwiftUI
        // hierarchy survives close and pane onDisappear never fires, leaking
        // nettop/process sampling retains. Tear down after close completes.
        let closing = window
        window = nil
        DispatchQueue.main.async {
            closing?.contentViewController = nil
        }
    }
}
