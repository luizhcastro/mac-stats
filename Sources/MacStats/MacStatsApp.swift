import SwiftUI
import AppKit

@main
struct MacStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var stats: SystemStats?
    var prefs: DisplayPreferences?
    var controller: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let stats = SystemStats()
        let prefs = DisplayPreferences()
        self.stats = stats
        self.prefs = prefs
        self.controller = StatusBarController(stats: stats, prefs: prefs)
    }
}
