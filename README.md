<p align="center">
  <img src="./design_handoff_macstats_logo/assets/png/macstats-256.png" width="128" height="128" alt="MacStats" />
</p>

<h1 align="center">MacStats</h1>

<p align="center">Open-source hardware monitoring for macOS. Lives in the menu bar.</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-blue">
  <img alt="Language" src="https://img.shields.io/badge/swift-6.3-orange">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

---

## Why

The macOS Activity Monitor is heavy and hidden in `/Applications/Utilities`. iStat Menus is excellent but paid. MacStats aims for the narrow middle: a menu-bar-first system monitor that shows CPU, RAM, disk, network, battery, and top processes at a glance — and stays out of your way.

## Features

- **Menu bar at-a-glance** — toggle any of CPU %, CPU temperature, memory used (GB), disk I/O rate, and network rate. Each metric is a separate status item, so macOS hides them individually when the menu bar gets crowded instead of dropping the whole group.
- **Dropdown detail** — live readouts for CPU (user / system / idle + sparkline), temperature (CPU / GPU / hottest sensor + thermal pressure), memory pressure, network up/down, disk R/W, battery state, and a tabbed list of top processes by CPU / RAM / Disk / Network / Energy.
- **Main window** — full-screen sidebar nav (Overview, CPU, Memory, Disk, Network, Battery, Temperature, Processes) with charts and a filterable / sortable process table.
- **Per-process insight** — top 8 apps by CPU / RAM / disk I/O / network bytes / energy impact, sorted in a background actor via `libproc`. Right-click to Quit or Force Kill (with a confirmation alert).
- **Per-process network** — bytes in / out per process via a long-running streaming `nettop` child, parsed from PTY stdout.
- **Temperature** — CPU / GPU / SOC sensors via private `IOHIDEventSystemClient`; thermal pressure via public `ProcessInfo.thermalState`.
- **Low idle cost** — expensive probes (process iteration, IOKit battery, volume capacity XPC, IOHID temperature, nettop process) only run while a consumer view is open, gated by independent refcounts. With the popover and main window closed, the app samples only cheap counters on a background actor. Typical idle: around 70 MB RAM, well under 1% CPU.
- **Stable UI** — fixed-width metric slots, Apple system menu font, frozen layout while the dropdown is open (no jitter when toggling), popover closes on any outside click.
- **Native** — Swift 6 (strict concurrency) + SwiftUI + AppKit. No Electron, no Python, no daemons, no third-party packages.
- **Zero config** — no accounts, no telemetry, no network calls.

## Screenshot

_(Capture the menu bar with CPU + RAM + Disk selected, and the open dropdown, and drop PNGs here.)_

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (arm64) — an Intel build is possible but not yet produced

## Install

### Prebuilt

Grab the latest `.app` from [Releases](../../releases), unzip, and move to `/Applications`.

Because the build is not signed with an Apple Developer ID yet, Gatekeeper will refuse it on first launch. Workaround:

- Right-click `MacStats.app` → **Open** → **Open** in the dialog, **or**
- System Settings → Privacy & Security → scroll to "MacStats was blocked" → **Open Anyway**.

### Build from source

```bash
git clone https://github.com/<you>/mac-stats.git
cd mac-stats
./Scripts/run.sh            # debug build + launch
./Scripts/bundle.sh release # production .app in .build/.../MacStats.app
```

Requirements: Xcode 15+ or the Swift 6.3 toolchain. No package dependencies.

## Usage

1. Launch the app — the status item appears in the menu bar.
2. Click any item to open the dropdown.
3. At the bottom of the dropdown, toggle **CPU / Temp / RAM / Disk / Network** to pick which metrics show in the menu bar. Selection persists across restarts.
4. Click the window icon in the dropdown header (or `⌘0`) to open the full main window.
5. **Quit** from the dropdown or press `⌘Q`.

No settings window; by design.

## Data sources

| Domain | API | Public? |
|---|---|---|
| CPU load | `host_statistics` with `HOST_CPU_LOAD_INFO` | yes |
| Memory | `host_statistics64` with `HOST_VM_INFO64` | yes |
| Network I/O | `getifaddrs` + `if_data` | yes |
| Disk I/O | IOKit `IOBlockStorageDriver` statistics | yes |
| Volumes | `URL.resourceValues(forKeys:)` | yes |
| Battery | `IOPowerSources` | yes |
| Per-process | `libproc` (`proc_listpids`, `proc_pidinfo`, `proc_pid_rusage`) | yes |
| Per-process network | `/usr/bin/nettop -P -x -J bytes_in,bytes_out` (streamed via PTY) | yes (CLI) |
| Thermal pressure | `ProcessInfo.processInfo.thermalState` | yes |
| CPU/GPU temperature | `IOHIDEventSystemClient` (Apple vendor temperature sensors) | private |

No SIP bypass, no kexts, no private entitlements. The temperature path uses private symbols declared via `@_silgen_name` — same approach as Stats.app and similar OSS monitors.

## Limitations

- **No fan RPM or SMC voltage / current sensors.** Private SMC keys vary per chip; not planned unless strictly needed. (CPU/GPU/SOC *temperatures* are supported via IOHID.)
- **Not yet signed / notarized.** Installation requires a Gatekeeper override (see above).
- **Apple Silicon only** in current releases. On Intel, the temperature view is hidden because the IOHID sensor matching dictionary returns no services.

## Project layout

```
Sources/MacStats/
├── MacStatsApp.swift            # @main, AppDelegate; pkill orphan nettops on launch/quit
├── StatusBarController.swift    # one NSStatusItem per metric, shared NSPopover
├── MainWindowController.swift   # NSWindowController hosting the main window
├── SystemStats.swift            # @MainActor ObservableObject + background sampling actor; refcounted detail/full-process/nettop tiers
├── DisplayPreferences.swift     # BarMetric enum + which metrics show in the bar (UserDefaults)
├── MenuBarSnapshot.swift        # frozen copy of prefs while the popover is open
├── Formatters.swift
├── ProcessKill.swift            # confirm-and-kill helper used by leader rows
├── Monitors/                    # one sampler per hardware domain
│   ├── CPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── DiskMonitor.swift
│   ├── BatteryMonitor.swift
│   ├── ProcessMonitor.swift
│   ├── NetworkProcessMonitor.swift  # spawns `nettop` via PTY
│   ├── TemperatureMonitor.swift     # IOHIDEventSystemClient
│   └── SamplingMath.swift           # shared delta / rate helpers
└── Views/
    ├── SingleMetricLabel.swift     # one metric in the menu bar (icon + compact value)
    ├── MenuBarContentView.swift    # dropdown content
    ├── MenuBarPrefsView.swift      # 3-col grid of menu bar metric checkboxes
    ├── TopProcessesView.swift      # tabbed top processes (CPU/RAM/Disk/Network/Energy)
    ├── MainWindowView.swift        # sidebar nav (Overview / Hardware / Activity)
    ├── PaneKit.swift               # PaneHeader, MetricCard, AreaSpark, DualAreaSpark
    └── Panes/
        ├── DashboardPane.swift     # at-a-glance card grid
        ├── MetricPanes.swift       # CPU / Memory / Disk / Network / Battery / Temperature
        └── ProcessesPane.swift     # full filterable / sortable process table

Resources/
└── AppIcon.icns                # bundled into the .app by Scripts/bundle.sh

design_handoff_macstats_logo/   # canonical icon source (SVG + sized PNGs + README)
```

See [`CLAUDE.md`](./CLAUDE.md) (mirrored at [`AGENTS.md`](./AGENTS.md)) for architecture notes, the popover-driven detail sampling design, tricky Darwin API shapes (`proc_pid_rusage`, `ProcessIdentity`), and guidance for AI agents working on the codebase.

## Contributing

Issues and PRs welcome. Keep it simple: this is meant to stay small.

Before opening a PR:
- `swift build -c release` passes
- `./Scripts/run.sh` launches cleanly and the menu bar behaves

No tests yet; manual verification is the bar.

## Credits

- Icon design: `design_handoff_macstats_logo/` — hand-authored SVG, Apple-style squircle with Liquid Glass material and three activity rings.
- Inspiration: [iStat Menus](https://bjango.com/mac/istatmenus/).

## License

MIT. See [LICENSE](./LICENSE).
