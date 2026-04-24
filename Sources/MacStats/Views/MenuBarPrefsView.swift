import SwiftUI

struct MenuBarPrefsView: View {
    @ObservedObject var prefs: DisplayPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Show in menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(BarMetric.allCases) { metric in
                    Toggle(isOn: Binding(
                        get: { prefs.isSelected(metric) },
                        set: { _ in prefs.toggle(metric) }
                    )) {
                        Label(metric.label, systemImage: metric.icon)
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(prefs.isSelected(metric) && prefs.selected.count == 1)
                }
                Spacer()
            }
        }
    }
}
