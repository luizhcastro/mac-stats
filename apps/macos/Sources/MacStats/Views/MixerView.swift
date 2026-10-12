import SwiftUI
import AppKit

/// Per-app volume rows. Used by the popover section and the Sound pane.
@available(macOS 14.4, *)
struct MixerView: View {
    @ObservedObject private var mixer = AudioMixer.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if mixer.apps.isEmpty {
                Text("No apps playing audio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(mixer.apps) { app in
                row(app)
                    .transition(.opacity)
            }
            if mixer.tapFailed {
                Text("MacStats needs System Audio Recording access (System Settings → Privacy & Security) to change app volumes.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(nil)  // the popover forces one line; this one is a sentence
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        // Rows slide to their new place when an app starts playing (it moves
        // to the top) instead of teleporting; arrivals/departures fade.
        .animation(Motion.spring(reduceMotion: reduceMotion), value: mixer.apps.map(\.id))
        .animation(Motion.spring(reduceMotion: reduceMotion), value: mixer.tapFailed)
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
                    .contentTransition(.symbolEffect(.replace))
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

/// Popover section: header counts what's playing, rows expand on demand.
@available(macOS 14.4, *)
struct SoundSection: View {
    @ObservedObject private var mixer = AudioMixer.shared

    var body: some View {
        PopoverSection("sound", expandedByDefault: false) {
            HStack {
                Label("Sound", systemImage: "speaker.wave.2")
                    .font(.headline)
                    .fixedSize()
                Spacer()
                let playing = mixer.apps.filter(\.isPlaying).count
                Text(playing == 0 ? "silent" : "\(playing) playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } detail: {
            MixerView()
        }
        // Keep the 1 s poll alive while collapsed too, so the count is right.
        .onAppear { mixer.retainView() }
        .onDisappear { mixer.releaseView() }
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
