import { useRef, useState, type PointerEvent } from 'react'
import { order } from '../../lib/motion'
import { DownloadButton } from '../DownloadButton'
import { TrafficLights } from '../TrafficLights'

/** The close: what to do on the left, the disk image window you'll see on the right */
export function Install() {
  return (
    <section id="install" aria-labelledby="install-title" className="page scroll-mt-16 pt-[clamp(6rem,14vw,12rem)]" style={order(3)}>
      <div className="grid items-center gap-x-16 gap-y-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
        <div>
          <h2 id="install-title" className="enter text-head leading-none font-bold tracking-[-0.035em]">
            Install in a minute
          </h2>
          <p className="enter mt-6 max-w-[26em] text-lead leading-snug">
            Download the disk image, drag MacStats into Applications and open it. Free, with no account.
          </p>
          <div className="enter mt-9">
            <DownloadButton source="install" />
          </div>
          <p className="enter mt-5 max-w-[30em] text-small text-muted">
            macOS 13 or later on Apple Silicon. Signed and notarized: macOS asks once whether to open an app from the
            internet, choose Open.
          </p>
        </div>

        <DiskImageWindow />
      </div>
    </section>
  )
}

/**
 * The window the .dmg opens, at a size you can play with: drag the icon onto Applications
 * (or focus it and press Return) and it "installs". Pointer events, so it works by touch too.
 * The icon stays inside the window's grey area, like an icon in a Finder window.
 */
function DiskImageWindow() {
  const [installed, setInstalled] = useState(false)
  const [offset, setOffset] = useState({ x: 0, y: 0 })
  const [dragging, setDragging] = useState(false)
  const [overFolder, setOverFolder] = useState(false)
  // The drag in progress: pointer origin, travel limits, the icon's resting centre, the folder's
  // rect (measured once, before its hover scale), the last offset and whether that's over the folder
  const drag = useRef({ active: false, x: 0, y: 0, minX: 0, maxX: 0, minY: 0, maxY: 0, cx: 0, cy: 0, folder: new DOMRect(), ox: 0, oy: 0, over: false })
  const area = useRef<HTMLDivElement>(null)
  const folder = useRef<HTMLDivElement>(null)

  function onPointerDown(e: PointerEvent<HTMLButtonElement>) {
    if (installed || e.button !== 0) return
    e.preventDefault() // no text selection or native image drag while dragging
    e.currentTarget.setPointerCapture(e.pointerId)
    // If it's still gliding home from the last drag, pick it up where it is, not where it's headed
    const { m41: tx, m42: ty } = new DOMMatrix(getComputedStyle(e.currentTarget).transform)
    const a = area.current!.getBoundingClientRect()
    const r = e.currentTarget.getBoundingClientRect()
    const rest = { left: r.left - tx, right: r.right - tx, top: r.top - ty, bottom: r.bottom - ty }
    drag.current = {
      active: true,
      x: e.clientX - tx,
      y: e.clientY - ty,
      minX: a.left - rest.left,
      maxX: a.right - rest.right,
      minY: a.top - rest.top,
      maxY: a.bottom - rest.bottom,
      cx: (rest.left + rest.right) / 2,
      cy: (rest.top + rest.bottom) / 2,
      folder: folder.current!.getBoundingClientRect(),
      ox: tx,
      oy: ty,
      over: false,
    }
    setOffset({ x: tx, y: ty })
    setDragging(true)
  }

  function onPointerMove(e: PointerEvent) {
    const d = drag.current
    if (!d.active) return
    d.ox = Math.min(Math.max(e.clientX - d.x, d.minX), d.maxX)
    d.oy = Math.min(Math.max(e.clientY - d.y, d.minY), d.maxY)
    // The icon's centre over the folder: the one test for both the highlight and the drop
    const cx = d.cx + d.ox
    const cy = d.cy + d.oy
    d.over = cx >= d.folder.left && cx <= d.folder.right && cy >= d.folder.top && cy <= d.folder.bottom
    setOffset({ x: d.ox, y: d.oy })
    setOverFolder(d.over)
  }

  // A ref, not state: lostpointercapture fires right after pointerup, before a re-render
  function endDrag(drop: boolean) {
    const d = drag.current
    if (!d.active) return
    d.active = false
    setDragging(false)
    setOverFolder(false)
    // Dropped while the folder was lit: it disappears into it where it was let go. Else: back home.
    if (drop && d.over) install()
    else setOffset({ x: 0, y: 0 })
  }

  function install() {
    setInstalled(true)
    playDropSound()
  }

  function reset() {
    setInstalled(false)
    setOffset({ x: 0, y: 0 })
  }

  const iconSize = 'size-[clamp(4.5rem,9vw,7rem)]'

  return (
    <div data-ui className="enter late glass glass-dark overflow-hidden rounded-[18px] text-[13px] text-label select-none">
      <div className="relative flex h-11 items-center px-4">
        <TrafficLights />
        <span className="pointer-events-none absolute inset-x-0 text-center font-semibold">MacStats</span>
      </div>

      <div
        ref={area}
        className="relative grid aspect-[16/10] grid-cols-[1fr_auto_1fr] items-center bg-stage px-[6%] pb-10 text-on-stage max-sm:aspect-[4/3]"
      >
        <figure className="grid justify-items-center gap-3">
          <button
            type="button"
            aria-label="Move MacStats into Applications"
            disabled={installed}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={() => endDrag(true)}
            onPointerCancel={() => endDrag(false)}
            onLostPointerCapture={() => endDrag(false)}
            // Return or Space fires a click with no pointer (detail 0); a real click ends a drag instead
            onClick={(e) => e.detail === 0 && install()}
            style={{ transform: `translate(${offset.x}px, ${offset.y}px)` }}
            className={`relative z-10 touch-none rounded-2xl p-2 ${dragging ? 'cursor-grabbing' : 'cursor-grab'} ${
              dragging ? '' : 'transition-[transform,scale,opacity] duration-300 ease-snappy'
            } ${installed ? 'scale-50 opacity-0' : ''}`}
          >
            <img src="/icon.webp" alt="" draggable={false} className={iconSize} />
          </button>
          <figcaption className={`transition-opacity duration-200 ${installed || dragging ? 'opacity-0' : ''}`}>MacStats</figcaption>
        </figure>

        <svg viewBox="0 0 80 24" className="w-[clamp(3rem,8vw,6rem)] fill-none stroke-current opacity-45" aria-hidden="true">
          <path d="M2 12h72M64 3l10 9-10 9" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>

        <figure className="grid justify-items-center gap-3">
          <div
            ref={folder}
            className={`relative rounded-2xl p-2 transition-[background-color,scale] duration-200 ease-snappy ${
              overFolder ? 'scale-105 bg-on-stage/12' : ''
            } ${installed ? 'animate-[folder-take_420ms_var(--ease-snappy)] motion-reduce:animate-none' : ''}`}
          >
            <FolderIcon className={iconSize} />
            {installed && <img src="/icon.webp" alt="" className="absolute right-0 bottom-1 size-[38%] animate-reveal" />}
          </div>
          <figcaption>Applications</figcaption>
        </figure>

        <p className="absolute inset-x-0 bottom-5 text-center" aria-live="polite">
          {installed ? (
            <>
              Installed. Now open it from Applications.{' '}
              <button type="button" onClick={reset} className="link cursor-pointer font-semibold">
                Again
              </button>
            </>
          ) : (
            'Drag MacStats onto Applications'
          )}
        </p>
      </div>
    </div>
  )
}

let audio: AudioContext | undefined

/**
 * A short glassy "pop" for the drop, synthesized so there's no sound file to ship (macOS plays
 * nothing when an app lands in Applications, and its system sounds aren't ours to host).
 * A sine that drops 40% in pitch from 880 Hz, plus a quieter bell partial, both gone in under 0.2 s.
 * Called from a pointer or key handler, so browsers allow the AudioContext to start.
 */
function playDropSound() {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return
  audio ??= new AudioContext()
  const t = audio.currentTime
  for (const [freq, peak, decay] of [
    [880, 0.22, 0.18],
    [880 * 2.76, 0.06, 0.09],
  ]) {
    const osc = audio.createOscillator()
    const gain = audio.createGain()
    osc.frequency.setValueAtTime(freq, t)
    osc.frequency.exponentialRampToValueAtTime(freq * 0.6, t + 0.12)
    gain.gain.setValueAtTime(0.0001, t)
    gain.gain.exponentialRampToValueAtTime(peak, t + 0.006)
    gain.gain.exponentialRampToValueAtTime(0.0001, t + decay)
    osc.connect(gain).connect(audio.destination)
    osc.start(t)
    osc.stop(t + decay + 0.02)
  }
}

/** The blue macOS folder with the Applications glyph, drawn flat */
function FolderIcon({ className }: { className: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <path d="M6 16a4 4 0 0 1 4-4h14l5 5h25a4 4 0 0 1 4 4v29a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4Z" fill="#3a8ee6" />
      <path d="M6 23a4 4 0 0 1 4-4h44a4 4 0 0 1 4 4v27a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4Z" fill="#62adf5" />
      <path d="M26 46 32 30l6 16M28.2 40.5h7.6" fill="none" stroke="#2f7fd3" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
