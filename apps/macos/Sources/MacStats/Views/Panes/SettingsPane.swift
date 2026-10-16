import SwiftUI
import AppKit

struct SettingsPane: View {
    @ObservedObject var prefs: DisplayPreferences
    @ObservedObject private var updates = UpdateChecker.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Settings", subtitle: "Menu bar, Dock, updates and privacy")

                MetricCard(title: "Menu bar", icon: "menubar.rectangle") {
                    MenuBarPrefsView(prefs: prefs)
                    Text("Pick which metrics show in the menu bar. \"App icon\" adds a plain MacStats icon you can click to open this dropdown, so you can keep the bar clean.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                MetricCard(title: "Dock", icon: "dock.rectangle") {
                    Toggle("Show MacStats in the Dock", isOn: $prefs.showDockIcon)
                        .toggleStyle(.checkbox)
                    Text("Off by default: MacStats lives in the menu bar only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                MetricCard(title: "Updates", icon: "arrow.down.circle") {
                    Text("Version \(updates.currentVersion ?? "dev")")
                    Button(updates.availableVersion.map { "Install MacStats \($0)…" } ?? "Check for Updates…") {
                        updates.checkForUpdates()
                    }
                    Text("MacStats checks for new releases daily and installs them in place.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                MetricCard(title: "Privacy", icon: "hand.raised") {
                    Toggle("Share anonymous usage statistics", isOn: $prefs.shareAnalytics)
                        .toggleStyle(.checkbox)
                    Text("Sends at most three pings a day (app running, dropdown opened, window opened) with the app version, macOS version, CPU architecture and a random install ID. No system metrics, processes or personal data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
    }
}
