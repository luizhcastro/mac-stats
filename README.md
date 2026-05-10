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
- **Dropdown detail** — live readouts for CPU (user / system / idle + load average + sparkline), temperature (CPU / GPU / hottest sensor + thermal pressure), memory (pressure + swap usage), network up/down, disk R/W, battery state, and a tabbed list of top processes by CPU / RAM / Disk / Network / Energy.
- **Main window** — full-screen sidebar nav (Overview, CPU, GPU, Memory, Disk, Network, Battery, Temperature, Fans, Processes) with charts and a filterable / sortable process table.
- **CPU detail** — per-core histogram split by P-cores and E-cores via `host_processor_info` + `hw.perflevel*.physicalcpu`, plus 1 / 5 / 15 min load averages.
- **GPU detail** — utilization, renderer / tiler breakdown, and vRAM in use via the IOAccelerator service tree (works on Apple Silicon and discrete GPUs).
- **Disk per-volume** — every mounted volume listed with capacity, free space, and SMART status badge (queried through `diskutil info -plist`, cached for 5 minutes).
- **Network detail** — per-interface bytes in / out, IPv4 / IPv6 addresses, plus a Wi-Fi card with SSID / RSSI / channel / band / Tx rate via CoreWLAN, and a public-IP lookup cached for 10 minutes.
- **Long-window history** — every chart in the main window has a `1m / 1h / 24h` switcher backed by three downsampled rings per metric (60 samples at 1 Hz, 360 at 10 s, 1440 at 1 min).
- **Battery detail** — cycle count, max capacity vs design (health %), voltage, current, temperature, and 30-minute history rings for charge % and signed wattage (charging vs draining).
- **Fans** — RPM, target, min / max per fan via a Swift SMC client (`AppleSMC`, `kSMCHandleYPCEvent`). Fanless Macs (e.g. M-series Air) get an explanatory empty state.
- **Per-process insight** — top 8 apps by CPU / RAM / disk I/O / network bytes / energy impact, sorted in a background actor via `libproc`. Right-click to Quit or Force Kill (with a confirmation alert).
- **Per-process network** — bytes in / out per process via a long-running streaming `nettop` child, parsed from PTY stdout.
- **Temperature** — CPU / GPU / SOC sensors via private `IOHIDEventSystemClient`; thermal pressure via public `ProcessInfo.thermalState`.
- **Low idle cost** — expensive probes (process iteration, IOKit battery, volume capacity XPC, IOHID temperature, GPU stats, SMC fans, Wi-Fi info, nettop process) only run while a consumer view is open, gated by independent refcounts. With the popover and main window closed, the app samples only cheap counters on a background actor. Typical idle: around 76 MB RAM, around 0.5 % CPU.
- **Stable UI** — fixed-width metric slots, Apple system menu font, frozen layout while the dropdown is open (no jitter when toggling), popover closes on any outside click.
- **Native** — Swift 6 (strict concurrency) + SwiftUI + AppKit. No Electron, no Python, no daemons, no third-party packages.
- **Zero config** — no accounts, no telemetry. The only outbound call is the public-IP lookup (`api.ipify.org`) used by the Wi-Fi pane; it only fires while the main window is open.

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
| CPU per-core | `host_processor_info` with `PROCESSOR_CPU_LOAD_INFO` | yes |
| CPU clusters | `sysctlbyname("hw.perflevel0/1.physicalcpu")` | yes |
| Load average | `getloadavg(3)` | yes |
| Memory | `host_statistics64` with `HOST_VM_INFO64` | yes |
| Memory swap | `sysctlbyname("vm.swapusage")` + `vm_statistics64.swapins/outs` | yes |
| Network I/O | `getifaddrs` + `if_data` | yes |
| Network per-interface IPs | `getifaddrs` + `getnameinfo(NI_NUMERICHOST)` | yes |
| Wi-Fi | `CoreWLAN` (`CWWiFiClient`, `CWInterface`) | yes |
| Public IP | `https://api.ipify.org` | external |
| Disk I/O | IOKit `IOBlockStorageDriver` statistics | yes |
| Volumes | `FileManager.mountedVolumeURLs` + `URL.resourceValues` | yes |
| SMART | `/usr/sbin/diskutil info -plist /dev/diskN` | yes (CLI) |
| Battery | `IOPowerSources` + `AppleSmartBattery` registry | yes |
| Per-process | `libproc` (`proc_listpids`, `proc_pidinfo`, `proc_pid_rusage`) | yes |
| Per-process network | `/usr/bin/nettop -P -x -J bytes_in,bytes_out` (streamed via PTY) | yes (CLI) |
| Thermal pressure | `ProcessInfo.processInfo.thermalState` | yes |
| CPU / GPU temperature | `IOHIDEventSystemClient` (Apple vendor temperature sensors) | private |
| GPU utilization / vRAM | IOKit `IOAccelerator` → `PerformanceStatistics` dictionary | yes (undocumented keys) |
| Fans | `AppleSMC` user client + `kSMCHandleYPCEvent` (`F<i>Ac/Mn/Mx/Tg/ID`) | private |

No SIP bypass, no kexts, no private entitlements. The temperature path uses private symbols declared via `@_silgen_name`; the SMC client talks to `AppleSMC` through the standard user client interface (same as `smc` CLI tools). Same approach as Stats.app and similar OSS monitors.

## Limitations

- **No SMC voltage / current sensors.** Fan RPM works (added in v0.3.0), but voltage and current SMC keys vary per chip family and aren't mapped.
- **Wi-Fi SSID needs Location permission** on macOS 13+. Without it the pane shows "Connected" but no SSID name.
- **Public IP is the only outbound call.** Disabled when the main window is closed; cached for 10 minutes when it runs.
- **Not yet signed / notarized.** Installation requires a Gatekeeper override (see above).
- **Apple Silicon only** in current releases. On Intel, the temperature, GPU, and fan panes hide themselves when their respective sensor sources return nothing.

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
│   ├── CPUMonitor.swift             # aggregate + per-core + load average
│   ├── MemoryMonitor.swift          # VM stats + swap usage and rates
│   ├── NetworkMonitor.swift         # aggregate + per-interface bytes / IPs
│   ├── WiFiMonitor.swift            # CoreWLAN SSID / RSSI / channel
│   ├── DiskMonitor.swift            # I/O + per-volume capacity + SMART
│   ├── BatteryMonitor.swift         # power source + AppleSmartBattery registry
│   ├── ProcessMonitor.swift
│   ├── NetworkProcessMonitor.swift  # spawns `nettop` via PTY
│   ├── TemperatureMonitor.swift     # IOHIDEventSystemClient
│   ├── GPUMonitor.swift             # IOAccelerator PerformanceStatistics
│   ├── SMCClient.swift              # AppleSMC user client wrapper
│   ├── FanMonitor.swift             # SMC F* keys → FanInfo[]
│   └── SamplingMath.swift           # shared delta / rate helpers
└── Views/
    ├── SingleMetricLabel.swift     # one metric in the menu bar (icon + compact value)
    ├── MenuBarContentView.swift    # dropdown content
    ├── MenuBarPrefsView.swift      # 3-col grid of menu bar metric checkboxes
    ├── TopProcessesView.swift      # tabbed top processes (CPU/RAM/Disk/Network/Energy)
    ├── MainWindowView.swift        # sidebar nav (Overview / Hardware / Activity)
    ├── PaneKit.swift               # PaneHeader, MetricCard, AreaSpark, DualAreaSpark, CenteredSpark, HistoryRangePicker
    └── Panes/
        ├── DashboardPane.swift     # at-a-glance card grid
        ├── MetricPanes.swift       # CPU / GPU / Memory / Disk / Network / Battery / Temperature / Fans
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
