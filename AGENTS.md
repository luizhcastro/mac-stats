# MacStats — Agent Guide

Native macOS menu bar system monitor. Inspired by iStat Menus. Personal use, not App Store.

## Product context

- Replace macOS Activity Monitor for quick glances at CPU/RAM/Disk/Network/Battery.
- Menu bar first: compact metrics always visible; dropdown for detail.
- Per-process tops (CPU/RAM/Disk) so the user can spot hogs without opening Activity Monitor.
- Target audience: the repo owner. No localization, no onboarding, no telemetry.

### Non-goals

- App Store distribution (no sandboxing, no notarization pipeline).
- Cross-platform. macOS 13+ only (uses modern SwiftUI APIs + IOKit).
- SMC voltage / current sensors. Keys vary per chip family and aren't mapped. (Fan RPM *is* supported via the SMC client added in v0.3.0; CPU/GPU/SOC temperatures via IOHID.)
- Threshold-based notifications and world clocks / weather (intentionally out of scope vs iStat Menus parity).

## Stack

- Swift 6.3 toolchain + Swift 6 **strict concurrency** language mode (`.swiftLanguageMode(.v6)` in `Package.swift`). Every `Sample` struct is `Sendable`.
- SwiftUI + AppKit (`NSStatusItem` for menu bar, SwiftUI for content).
- Swift Package Manager (no Xcode project). `Package.swift` is the source of truth.
- macOS 13+ deployment target.
- No external dependencies.

## Build / run

```bash
./Scripts/run.sh           # debug bundle + launch
./Scripts/bundle.sh release  # release .app
swift build -c debug       # compile only
pkill -x MacStats          # kill running instance
```

`run.sh` wraps the SPM binary into a proper `.app` with `Info.plist` (sets `LSUIElement=true` so the app has no Dock icon). `bundle.sh` also copies `Resources/AppIcon.icns` into the bundle and wires `CFBundleIconFile = AppIcon` so Finder / About show the MacStats icon.

When iterating, kill before rebuild (`pkill -x MacStats`). If a change looks like it didn't apply, run `swift package clean` — SPM has occasionally served stale binaries in this repo.

## Architecture

```
Sources/MacStats/
├── MacStatsApp.swift            # @main, AppDelegate; spawns StatusBarController + MainWindowController; pkill orphan nettops on launch/quit
├── StatusBarController.swift    # owns N NSStatusItems (one per metric) + shared NSPopover; retains detail + nettop sampling while popover is shown
├── MainWindowController.swift   # NSWindowController hosting MainWindowView (sidebar + detail panes)
├── SystemStats.swift            # @MainActor ObservableObject + actor StatsSampler; refcounted detail/full-process/nettop tiers; ThermalLevel enum
├── DisplayPreferences.swift     # BarMetric enum + which metrics show in menu bar (UserDefaults-backed)
├── MenuBarSnapshot.swift        # frozen copy of selected metrics for the status bar
├── Formatters.swift             # byte/rate/percent formatting
├── ProcessKill.swift            # confirm-and-kill helper used by leader rows
├── Monitors/                    # stateless-ish samplers, one per hardware domain
│   ├── CPUMonitor.swift         # aggregate host_statistics + per-core host_processor_info + getloadavg
│   ├── MemoryMonitor.swift      # host_statistics64 HOST_VM_INFO64 + vm.swapusage + swap-in/out rates
│   ├── NetworkMonitor.swift     # getifaddrs + if_data; per-iface IPs gated to detail tier
│   ├── WiFiMonitor.swift        # CoreWLAN: SSID, RSSI, channel/band/width, txRate
│   ├── DiskMonitor.swift        # IOKit IOBlockStorageDriver + per-volume capacity + diskutil SMART
│   ├── BatteryMonitor.swift     # IOPowerSources + AppleSmartBattery registry
│   ├── ProcessMonitor.swift     # libproc: proc_listpids + PROC_PIDTASKALLINFO + rusage
│   ├── NetworkProcessMonitor.swift  # spawns `nettop` and parses per-process bytes_in/out
│   ├── TemperatureMonitor.swift # private IOHIDEventSystemClient: CPU/GPU/SOC thermal sensors
│   ├── GPUMonitor.swift         # IOAccelerator → PerformanceStatistics utilization + vRAM
│   ├── SMCClient.swift          # AppleSMC user client (kSMCHandleYPCEvent dispatch)
│   ├── FanMonitor.swift         # SMC F<i>Ac/Mn/Mx/Tg/ID → FanInfo[]
│   └── SamplingMath.swift       # shared delta / rate helpers (handles counter rollover)
└── Views/
    ├── SingleMetricLabel.swift     # one metric in the menu bar (icon above compact value)
    ├── MenuBarContentView.swift    # dropdown / popover content (header + sections + prefs + quit)
    ├── MenuBarPrefsView.swift      # 3-col grid of checkboxes for which metrics show in bar
    ├── TopProcessesView.swift      # tabbed top processes (CPU/RAM/Disk/Network/Energy)
    ├── MainWindowView.swift        # sidebar nav (Overview / Hardware / Activity)
    ├── PaneKit.swift               # shared pane primitives: PaneHeader, MetricCard, AreaSpark, DualAreaSpark, ScaleHelper
    └── Panes/
        ├── DashboardPane.swift     # at-a-glance card grid (cpu, mem, network, disk, battery, temperature)
        ├── MetricPanes.swift       # CPU / GPU / Memory / Disk / Network / Battery / Temperature / Fans + LeaderList
        └── ProcessesPane.swift     # full filterable / sortable process table

Resources/
└── AppIcon.icns                # built via iconutil from design_handoff_macstats_logo/

design_handoff_macstats_logo/   # canonical icon source (SVG + sized PNGs + README)
```

### Data flow

1. `SystemStats` (MainActor `ObservableObject`) holds one `@Published snapshot: SystemSnapshot`. `SystemSnapshot` is a `Sendable` value type bundling every monitor's latest `Sample` + the CPU history array + pre-sorted `ProcessLeaders` (top N per CPU/RAM/Disk).
2. Sampling runs in a **separate `actor StatsSampler`**, off the main thread. `SystemStats.init` starts a `Task` loop that calls `await sampler.sample(...)` every 1s and assigns the returned snapshot to `snapshot`. Views observe `snapshot` via `@Published` and see atomic, consistent updates.
3. Per-field accessors (`stats.cpu`, `stats.memory`, `stats.disk`, `stats.processLeaders`, …) are thin computed vars that read `snapshot`. Existing view code keeps working unchanged.
4. Counters that can wrap (CPU ticks, network / disk bytes, per-process rusage) all go through `SamplingMath.delta` / `SamplingMath.rate`, which guards `current >= previous` before subtracting.

### Detail sampling (refcount-gated)

Sampling is split into two tiers to keep idle cost low:

- **Always-on, cheap**: CPU (aggregate + per-core), memory + swap (sysctl), network aggregate counters, disk I/O rate, thermal pressure (`ProcessInfo.thermalState`). Every tick.
- **Detail-only, expensive**: battery (IOKit power source query), full process list (iterating every PID + `proc_pidinfo` + rusage), per-volume capacity / SMART (`URL.resourceValues` XPC + `diskutil info -plist` spawn), per-interface IPv4 / IPv6 enrichment (`getnameinfo`), Wi-Fi info (CoreWLAN), GPU stats (IOAccelerator copy), fan readings (SMC user client), temperature (IOHID event copy across all sensors), public IP (HTTPS request).

`SystemStats` exposes three independent **refcount** APIs instead of plain on/off setters:

- `retainDetailSampling()` / `releaseDetailSampling()` — toggles the detail tier.
- `retainFullProcessListEnabled()` / `releaseFullProcessListEnabled()` — populates `snapshot.allProcesses` (consumed only by the full process table). Detail tier already populates `processLeaders`.
- `retainNetworkProcessSampling()` / `releaseNetworkProcessSampling()` — starts/stops the long-running `nettop` child.

Each consumer (popover, NetworkPane, ProcessesPane) calls retain on appear / open and release on disappear / close. The first retain transitions the tier on; the last release transitions it off. This means the popover can stay closed while the main window keeps a network/process view alive — and conversely, opening the popover doesn't double-spawn nettop.

Additional cadences inside the detail tier:

- Battery: every 30 ticks (~30 s) — a `lastBatterySampleTick` counter spaces it out. Each refresh appends to a 60-slot ring (= 30 min of charge % + signed wattage history).
- Processes: every 2 ticks when detail sampling is on.
- Volume stats: cached for 30 s; SMART per disk cached for 5 min.
- Temperature: every 5 ticks (~5 s) — `lastTemperatureSampleTick`. CPU temp is pushed into a 60-sample ring every tick (repeats last sample) so the sparkline is smooth. Sampling is also kept alive outside the detail tier when the user has the temperature metric selected in the menu bar (`StatusBarController` calls `setTemperatureAlwaysOn(true)` on prefs change), so a visible status item stays current even with the popover and main window closed.
- GPU + Fans: every 5 ticks (~5 s) — `lastGPUSampleTick` / `lastFansSampleTick`. Both fail-closed (`hasReadings = false`) on hardware that doesn't expose the sensors, and the sidebar entry hides itself.
- Public IP: kicked from the actor as a detached `Task` when the cache is older than 10 min; `applyPublicIP(_:)` writes back through actor isolation.

Long-window history: each "rate" metric (CPU, memory %, network in/out, disk read/write, temperature) is fed into a `MetricRings` bundle that keeps three rings — 60 samples @ 1 Hz (`minute`), 360 samples @ 10 s (`hour`), and 1440 samples @ 1 min (`day`) — using rolling-average downsampling. Panes use a `HistoryRangePicker` to switch the rendered series.

When the popover opens, `setDetailSamplingEnabled(true)` also calls `refresh(forceDetailRefresh: true)` so the dropdown shows fresh numbers immediately instead of waiting up to 30 s for the next battery / temperature / volume-stats refresh.

### Menu bar rendering

- **One `NSStatusItem` per metric** (CPU, Temperature, RAM, Disk, Network — five total `BarMetric` cases). Not a single item with a multi-slot label. This lets macOS hide items individually under width pressure instead of collapsing the whole group at once. Each item owns an `NSHostingView<SingleMetricLabel>`.
- All items are **created once at launch** and toggled via `item.isVisible` when the user checks/unchecks a metric. Recreating items on every toggle turned out to be flaky (items occasionally failed to reappear).
- Items share **one `NSPopover`** (`behavior = .transient`, no animation). Clicking any item's button opens the popover anchored to that button.
- Popover closes on outside click via a **global `NSEvent.addGlobalMonitorForEvents`** monitor for `leftMouseDown`/`rightMouseDown`. `.transient` alone is unreliable, especially when items get hidden.
- Menu bar label uses `Font.system(size: 9, weight: .bold).monospacedDigit()` with compact suffixes (`99%`, `9.9G`, `1.2M`, `65°`) and fixed-width frames per metric.

### Freezing the menu bar while the popover is open

Toggling `DisplayPreferences` while the popover is visible is buffered via `MenuBarSnapshot`:

1. `StatusBarController` subscribes to `prefs.$selected`.
2. While the popover is shown, changes go into `pendingSnapshot` instead of updating `snapshot.selected` / `item.isVisible`.
3. On `popoverDidClose`, the pending snapshot is flushed and visibility is applied.

Without this, the status item layout would shift during a popover session, causing focus loss and popover drift.

## Non-obvious technical decisions

### Per-process network via `nettop`

macOS does not expose per-process network counters through libproc. The two stable paths are NEPacketTunnelProvider (needs entitlements + root) and parsing `nettop` output. We use the latter.

`NetworkProcessMonitor` spawns `/usr/bin/nettop -P -x -J bytes_in,bytes_out -s 2 -n -L 0` as a long-running streaming process and parses snapshots delimited by `time,…` header lines. Output rows are `time,name.pid,bytes_in,bytes_out,`. Parse: split on `,`, then split the second field on its **last** `.` because process names can themselves contain dots (e.g. `2.1.126.84762`).

Critical: nettop **block-buffers stdout when its output is not a TTY**. Spawning it with a regular `Pipe()` produces zero output until the buffer fills (which can take minutes), so the network tab appears empty. Allocate a PTY via `openpty()` and pass the slave fd as the process's `standardOutput` (and `standardInput`). Read from the master `FileHandle` via `readabilityHandler`. The line discipline forces line-buffered flushes. Side effect: lines are terminated with `\r\n` instead of `\n` — the trailing `\r` lands after the 4th comma so the field parsers are unaffected, and the header marker `"time,"` still matches at position 0.

Counters are cumulative bytes since process start, so we delta against the previous sample. Cache key is `pid` + name match — if the name changes between samples we treat it as a recycled PID and reset baseline (no spurious huge delta).

Lifecycle is **refcount-gated** via `retainNetworkProcessSampling()` / `releaseNetworkProcessSampling()`, called from `StatusBarController.openPopover` (popover anchor), `NetworkPane.onAppear`, and `ProcessesPane.onAppear`. The streaming nettop process only runs while at least one consumer is active.

`stop()` kills nettop in three layers:
1. `readabilityHandler = nil` + `masterHandle.closeFile()` — next nettop write hits SIGPIPE.
2. `process.terminate()` — SIGTERM immediately.
3. `kill(pid, SIGKILL)` after a 0.5 s grace if the process is still alive.

Typical shutdown takes ~10–50 ms (SIGTERM resolves it); hard cap is 500 ms.

`AppDelegate.killOrphanNettops()` runs on both `applicationDidFinishLaunching` and `applicationWillTerminate` — it `pkill -f`s any leftover nettop processes matching our exact arguments, covering the rare case where MacStats was killed with SIGKILL and couldn't run its own teardown.

### Temperature via private IOHID

CPU/GPU/SOC temperatures are read via the private `IOHIDEventSystemClient` API. Public alternatives don't exist on Apple Silicon: SMC keys are largely deprecated, and `ProcessInfo.thermalState` only exposes a coarse pressure level (nominal/fair/serious/critical), not absolute Celsius readings.

`TemperatureMonitor` declares the symbols via `@_silgen_name` (no public header), creates a single `IOHIDEventSystemClient` at init, sets a matching dictionary for `PrimaryUsagePage = 0xff00 / PrimaryUsage = 0x0005` (Apple vendor temperature sensors), and copies the matching services array once. Each service is classified once at init by name substring (e.g. `pACC`, `eACC`, `PMP`, `SOC` → CPU; `GPU` → GPU). The classification is stored as an aligned `[Category]` array, so the per-tick path is a tight `for i in 0..<services.count` loop with O(1) lookups and no Swift heap allocations beyond the (immediately released) per-event CFType.

The sample produces aggregate `cpuCelsius`, `gpuCelsius`, `maxCelsius`, `sensorCount` — not a per-sensor list, so views never trigger array allocation per refresh.

Thermal pressure (`ProcessInfo.processInfo.thermalState`) is read every tick — it's a free property read and lives outside the detail tier. The dropdown / dashboard / temperature pane all show the pressure label colored by severity.

On Intel Macs (or any system without IOHID temperature services), `services.isEmpty` is true and `Sample.hasReadings` is false; the menu bar item, dropdown section, sidebar entry, and dashboard card all hide themselves.

### `proc_pid_rusage` pointer shape

Darwin headers declare `typedef void *rusage_info_t;` and `int proc_pid_rusage(int, int, rusage_info_t *)`. The `rusage_info_t *` is misleading — the kernel writes struct data **directly** to the passed pointer, not through double indirection. The struct is `rusage_info_v2`.

In Swift this imports as `UnsafeMutablePointer<rusage_info_t?>`. Passing `&someStruct` naively causes the kernel to overrun the stack (`__stack_chk_fail` / SIGABRT) because the kernel writes ~144 bytes starting at the "pointer variable" rather than at the struct.

`ProcessMonitor` allocates the buffer **once** in the initializer (`rusageBuffer`) and reuses it for every PID each tick, rather than allocating per call:

```swift
private let rusageBuffer = UnsafeMutableRawPointer.allocate(
    byteCount: max(MemoryLayout<rusage_info_v2>.size, 4096),
    alignment: 16
)

let casted = UnsafeMutablePointer<rusage_info_t?>(OpaquePointer(rusageBuffer))
let ret = proc_pid_rusage(pid, RUSAGE_INFO_V2, casted)
```

The `OpaquePointer` cast is load-bearing. Keep both the single shared heap buffer and the cast if you refactor.

### `proc_listpids` slack

The two-call pattern (probe size, then fetch) races against process creation. A PID spawning between the calls can cause a buffer overflow. Always allocate extra slack bytes (see `listPids()` — uses `probe + 1024 * sizeof(pid)` slack) and clamp the result to the buffer capacity.

### ProcessIdentity as the cache key

`ProcessMonitor` keys its prior-sample cache on `ProcessIdentity { pid, startSeconds, startMicroseconds }`, not on raw `pid`. PIDs get recycled; if a short-lived process exits and a new one takes the same PID, keying on PID alone produces nonsensical CPU/disk deltas. `pbi_start_tvsec` / `pbi_start_tvusec` from `proc_taskallinfo` uniquely identify a process instance.

### One `proc_pidinfo` call per process

Use `PROC_PIDTASKALLINFO` instead of separate `PROC_PIDTASKINFO` + `proc_name` calls. `proc_taskallinfo` returns both the task info (CPU ticks, RSS) and the BSD info (name, command, start time) in a single syscall, and `pbi_name` / `pbi_comm` are decoded via `decodeCStringTuple` without another kernel hop.

### Fonts

Use `.font(.system(size: N))` with `.monospacedDigit()` — not `.system(design: .monospaced)`. Full monospaced design looks wrong in the menu bar; digit-only monospacing keeps SF for labels and fixes value-width jitter.

### Recreating vs hiding status items

Calling `NSStatusBar.system.removeStatusItem(...)` and then creating a new `NSStatusItem` to re-add it worked in isolation but was unreliable in practice — newly re-added items occasionally failed to appear. Keep all items alive for the app's lifetime and toggle `isVisible` instead.

### MenuBarExtra vs NSStatusItem

SwiftUI `MenuBarExtra` was tried first. It collapses complex label layouts: only one child of a multi-view `HStack` typically survives into the menu bar. `NSStatusItem` with an embedded `NSHostingView` is the reliable path.

### Volume capacity probes are not free

`URL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])` triggers an XPC roundtrip to the cache-delete daemon and spams the log with `CacheDelete` entries. `DiskMonitor.sample(includeVolumeStats:)` guards on the flag so this only happens when the popover is open, and even then the value is cached for 30 s.

## App icon

- Canonical source: `design_handoff_macstats_logo/assets/macstats-icon.svg` (hand-authored, see the folder's README for design tokens / geometry).
- Sized PNGs are in `design_handoff_macstats_logo/assets/png/`.
- Compiled `.icns` at `Resources/AppIcon.icns`. Rebuild it from the PNGs via `iconutil -c icns MacStats.iconset` (see the handoff README for the exact `.iconset` layout).
- `bundle.sh` copies the `.icns` into `Contents/Resources/AppIcon.icns` and sets `CFBundleIconFile = AppIcon`.
- The dropdown header in `MenuBarContentView` loads the same icon via `NSImage(named: "AppIcon")`.
- No mono/template variant for the menu bar; the colored bar glyphs come from SF Symbols in `SingleMetricLabel`.

## Adding a new monitor

1. New file in `Monitors/` exposing a `Sendable struct Sample` + `func sample() -> Sample`. Use `SamplingMath.rate` / `SamplingMath.delta` for counter math.
2. Add the sample to `SystemSnapshot` (field + `empty` default) and add an accessor on `SystemStats`.
3. In the `StatsSampler` actor: hold the monitor instance, call `sample()` in `sample(...)`, and include the result when building the returned `SystemSnapshot`. Decide whether it belongs in the always-on tier (cheap, every tick) or should gate on `detailSamplingEnabled` (expensive) — mirror the battery / processes / volume-stats cadence helpers if you need interval spacing.
4. Add a section in `MenuBarContentView` if it needs dropdown UI.
5. If it should be toggleable in the menu bar:
   - Add a case to `BarMetric` in `DisplayPreferences.swift` (the `MenuBarPrefsView` checkbox list updates automatically).
   - Extend `SingleMetricLabel` with the new `case` (icon, text, slot width).
   - Extend `StatusBarController.buildAllStatusItems` so the new metric gets its own `NSStatusItem`.

## Working on this codebase

- Test changes by running the app; there are no unit tests. SwiftUI Previews would require Xcode project (currently SPM-only).
- User runs macOS 26 / Apple Silicon. APIs verified there.
- Crash reports land in `~/Library/Logs/DiagnosticReports/Retired/MacStats-*.ips`. Parse with `python3 -c 'import json; ...'` and inspect triggered thread frames for source lines.
- Commits must not include `Co-Authored-By` (per global user rules). Keep commits granular and in English.
