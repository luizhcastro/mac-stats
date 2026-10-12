import SwiftUI
import AppKit

/// Per-app volume rows. Used by the popover section and the Sound pane.
@available(macOS 14.4, *)
struct MixerView: View {
    @ObservedObject private var mixer = AudioMixer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if mixer.apps.isEmpty {
                Text("No apps playing audio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(mixer.apps) { app in
                row(app)
            }
            if mixer.tapFailed {
                Text("MacStats needs System Audio Recording access (System Settings → Privacy & Security) to change app volumes.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(nil)  // the popover forces one line; this one is a sentence
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { mixer.retainView() }
        .onDisappear { mixer.releaseView() }
    }

    private func row(_ app: MixerApp) -> some View {
        HStack(spacing: 8) {
            Group {
                if let iconPath = app.iconPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: iconPath)).resizable()
                } else {
                    Image(systemName: "terminal").foregroundStyle(.secondary)
                }
            }
            .frame(width: 18, height: 18)
            Text(app.name)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
                .foregroundStyle(app.isPlaying ? .primary : .secondary)
            Button {
                mixer.setMuted(!app.muted, for: app.id)
            } label: {
                Image(systemName: app.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 18)
            }
            .buttonStyle(.borderless)
            .help(app.muted ? "Unmute" : "Mute")
            Slider(value: Binding(
                get: { Double(app.volume) },
                set: { mixer.setVolume(Float($0), for: app.id) }
            ), in: 0...1)
            .controlSize(.small)
            .disabled(app.muted)
            Text(Fmt.percent(Double(app.volume) * 100))
                .monospacedDigit()
                .font(.caption)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

@available(macOS 14.4, *)
struct SoundPane: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader(title: "Sound", subtitle: "Per-app volume")
                MetricCard(title: "Apps", icon: "speaker.wave.2") {
                    MixerView()
                    Text("Volumes are saved per app and re-applied whenever it plays. Browsers mix every tab into one process, so a browser is one row.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
    }
}
