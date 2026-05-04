import SwiftUI

struct MenuBarPrefsView: View {
    @ObservedObject var prefs: DisplayPreferences

    private let columns: [GridItem] = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Show in menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(BarMetric.allCases) { metric in
                    Toggle(isOn: Binding(
                        get: { prefs.isSelected(metric) },
                        set: { _ in prefs.toggle(metric) }
                    )) {
                        Label(metric.label, systemImage: metric.icon)
                            .font(.caption)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(prefs.isSelected(metric) && prefs.selected.count == 1)
                }
            }
        }
    }
}
