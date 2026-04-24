# Handoff: MacStats — App Icon

## Overview
Final app icon for **MacStats**, an open-source macOS hardware-monitoring utility. This package contains everything a developer needs to ship the icon with the Mac app (`.icns` bundle + individual PNGs), embed it in docs/README, and reproduce the design in-app if needed.

## About the Design Files
The HTML files in this bundle (`design-preview/`) are **design references** — prototypes showing intended look, sizing, and in-context behavior. They are not production code.

The **canonical source of truth is `assets/macstats-icon.svg`** — a hand-written, dependency-free SVG (~4.6 KB) that renders identically in browsers, image-editing tools, and `librsvg`/`rsvg-convert` (used by `iconutil`/build scripts). Use the PNGs in `assets/png/` for the `.icns` bundle and for GitHub README embeds.

## Fidelity
**High-fidelity.** All colors, gradients, geometry, and sizing values are finalized. A developer should not reinterpret — pixel values, hex codes, and SVG path data are authoritative.

## The Icon

### Concept
- **Metaphor:** three concentric activity rings (outer → inner) representing the three core hardware dimensions the app monitors (e.g. CPU / Memory / Disk). Each ring is a partial arc — implying live, variable system activity, not a static decoration.
- **Form:** Apple "squircle" (superellipse) silhouette, matching macOS Big Sur / Tahoe app-icon grid.
- **Material:** Liquid Glass (macOS Tahoe / iOS 26). Dark graphite base, top-left refracted light highlight, bottom-right depth shadow, thin bright rim highlight at the top edge, specular sheen on the top of each ring.
- **Center:** subtle translucent glass bead with a small white highlight — visual anchor + optical "pupil" of the composition.
- **Personality:** technical, precise, Apple-like; reads as a system utility rather than a consumer app.

### Squircle geometry
1024×1024 canvas. Single path (the Apple-style smooth superellipse):
```
M512,0 C181,0 0,181 0,512 C0,843 181,1024 512,1024 C843,1024 1024,843 1024,512 C1024,181 843,0 512,0 Z
```

### Rings (centered at 512,512; `stroke-width: 54`; `stroke-linecap: round`; `rotate(-90 512 512)` so arcs start at 12 o'clock)
| Ring | Radius | Fill % of circumference | Gradient (top-left → bottom-right) |
|---|---|---|---|
| Outer | 310 | 74% | `#ffffff` → `#b9bec6` |
| Middle | 236 | 58% | `#d6dae1` → `#7a7f87` |
| Inner | 162 | 40% | `#a0a4ac` → `#515660` |

Each ring also has:
- A **track** drawn first: same radius, `stroke: rgba(0,0,0,0.22)`, same width.
- A **specular sheen** drawn on top of the fill: 45% of the fill's arc length, `stroke-width: 48` (fill width − 6), `opacity: 0.85`, using the `#spec` gradient (white 0.9 → white 0).

### Central glass bead
- `circle cx=512 cy=512 r=70 fill=rgba(255,255,255,0.12)`
- `circle cx=512 cy=512 r=70 fill=none stroke=rgba(255,255,255,0.35) strokeWidth=2`
- Small highlight: `circle cx=490 cy=490 r=20 fill=rgba(255,255,255,0.5)`

### Liquid-Glass treatment (layer order inside the clipped squircle)
1. **Base gradient** (`#base`, vertical): `#4a4f57` (0%) → `#2a2e35` (50%) → `#14161a` (100%)
2. **Refracted light** (`#refract`, radial at 25%/20%, r 90%): white 0.55 → 0.12 → 0
3. Rings + central bead (as above)
4. **Depth shadow** (`#depth`, radial at 75%/80%, r 70%): transparent at 0.45 → black 0.35 at 1
5. **Rim highlight** (on top, not clipped) (`#rim`, vertical, stroke 4 on the squircle path): white 0.9 (0%) → white 0.15 (8%) → 0 (50%) → 0 (100%)
6. **Outer hairline** (stroke 1.5 on the squircle path): `rgba(0,0,0,0.4)`

### Drop shadow (outside the squircle, for floating contexts)
```
filter: drop-shadow(0 size*0.015px size*0.03px rgba(0,0,0,0.22))
        drop-shadow(0 size*0.05px  size*0.10px rgba(0,0,0,0.25))
```
where `size` is the render size in px.

## Design Tokens

### Palette
| Token | Hex | Usage |
|---|---|---|
| `graphite-0` | `#14161a` | Base bottom |
| `graphite-1` | `#2a2e35` | Base mid |
| `graphite-2` | `#4a4f57` | Base top |
| `silver-0` | `#ffffff` | Outer ring highlight |
| `silver-1` | `#b9bec6` | Outer ring shadow |
| `silver-2` | `#d6dae1` | Mid ring highlight |
| `silver-3` | `#7a7f87` | Mid ring shadow |
| `silver-4` | `#a0a4ac` | Inner ring highlight |
| `silver-5` | `#515660` | Inner ring shadow |

### Size ladder (provided as PNG)
`16, 32, 64, 128, 256, 512, 1024` — all square. Standard `.icns` set. Each is a straight raster of `macstats-icon.svg`.

For Retina, pair each nominal size with 2× (e.g. `icon_16x16.png` + `icon_16x16@2x.png` which is the 32px render). `iconutil` expects these names inside an `icon.iconset` folder.

## Files

```
design_handoff_macstats_logo/
├── README.md                           ← this file
├── assets/
│   ├── macstats-icon.svg               ← canonical source (1024×1024)
│   └── png/
│       ├── macstats-16.png
│       ├── macstats-32.png
│       ├── macstats-64.png
│       ├── macstats-128.png
│       ├── macstats-256.png
│       ├── macstats-512.png
│       └── macstats-1024.png
└── design-preview/
    ├── MacStats Logo Final.html        ← open this in a browser to preview
    ├── macstats-icon.jsx               ← React component (if embedding live)
    ├── macstats-final.jsx              ← showcase page
    └── design-canvas.jsx               ← preview harness only; not shipped
```

## Building a `.icns`
From the `assets/png/` folder:

```bash
# 1. Create the iconset folder
mkdir MacStats.iconset
cp macstats-16.png    MacStats.iconset/icon_16x16.png
cp macstats-32.png    MacStats.iconset/icon_16x16@2x.png
cp macstats-32.png    MacStats.iconset/icon_32x32.png
cp macstats-64.png    MacStats.iconset/icon_32x32@2x.png
cp macstats-128.png   MacStats.iconset/icon_128x128.png
cp macstats-256.png   MacStats.iconset/icon_128x128@2x.png
cp macstats-256.png   MacStats.iconset/icon_256x256.png
cp macstats-512.png   MacStats.iconset/icon_256x256@2x.png
cp macstats-512.png   MacStats.iconset/icon_512x512.png
cp macstats-1024.png  MacStats.iconset/icon_512x512@2x.png

# 2. Build the .icns
iconutil -c icns MacStats.iconset
# → produces MacStats.icns
```

Then drop `MacStats.icns` into your Xcode project and set it as the app's bundle icon (`CFBundleIconFile` in `Info.plist` or via the target's "App Icon" setting).

## Embedding in a React/SwiftUI app
- **React / web docs:** `<img src="./macstats-icon.svg" width="96" height="96" alt="MacStats" />` or paste the SVG inline.
- **SwiftUI (if rendering live in-app, e.g. About screen):** drop `macstats-icon.svg` into Assets.xcassets as a vector image set and use `Image("macstats-icon").resizable().frame(width: 96, height: 96)`.
- **Menu bar status item:** use the `16.png` (or a 2× 32.png) — because the icon is NOT pure monochrome, do **not** apply `.template` rendering mode; use `.original`. If you need a true template variant for strict HIG compliance in the menu bar, ask the designer for a separate mono cut — this spec does not include one.

## GitHub README usage
Drop `assets/png/macstats-256.png` at the top of the README, centered:

```markdown
<p align="center">
  <img src="./assets/macstats-256.png" width="128" height="128" alt="MacStats" />
</p>
<h1 align="center">MacStats</h1>
<p align="center">Open-source hardware monitoring for macOS.</p>
```

## Notes for future iterations
- **Ring fill percentages** (74 / 58 / 40) were chosen for visual balance, not as a live readout. If you want the app-icon to animate with real system load, keep the outer/mid/inner mapping (CPU / RAM / Disk) but feel free to vary — the current values look "healthy/busy" at a glance.
- **Mono / template variant** (for strict menu-bar HIG): not included. The icon was designed to keep color in all contexts.
- **Dark-mode Finder list:** icon is already dark, so it sits well. No alternate cut needed.
