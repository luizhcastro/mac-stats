import SwiftUI

struct SettingsPane: View {
    @ObservedObject var prefs: DisplayPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Settings", subtitle: "Menu bar and Dock")

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
            }
            .padding(20)
        }
    }
}
