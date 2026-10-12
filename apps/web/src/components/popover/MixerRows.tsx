import type { Mixer } from '../../lib/mixer'

/** Per-app volume rows (icon, name, mute, slider, percent), mirrors MixerView.swift */
export function MixerRows({ mixer, compact = false }: { mixer: Mixer; compact?: boolean }) {
  return (
    <ul className={`grid ${compact ? 'gap-1.5 text-[13px]' : 'gap-2.5 text-sm'}`}>
      {mixer.apps.map((app) => (
        <li key={app.id} className="flex items-center gap-2">
          <img src={app.icon} alt="" className="size-[18px] flex-none" />
          <span className={`w-[110px] flex-none truncate ${app.playing ? '' : 'text-secondary'}`}>{app.name}</span>
          <button
            type="button"
            onClick={() => mixer.toggleMute(app.id)}
            aria-label={app.muted ? `Unmute ${app.name}` : `Mute ${app.name}`}
            title={app.muted ? 'Unmute' : 'Mute'}
            className="cursor-pointer rounded p-0.5 text-secondary hover:text-label"
          >
            <MuteSymbol muted={app.muted} />
          </button>
          <input
            type="range"
            min={0}
            max={100}
            value={Math.round(app.volume * 100)}
            disabled={app.muted}
            onChange={(e) => mixer.setVolume(app.id, Number(e.target.value) / 100)}
            aria-label={`${app.name} volume`}
            className="h-1 w-0 min-w-0 flex-1 cursor-pointer accent-white disabled:cursor-default disabled:opacity-40"
          />
          <span className="w-9 flex-none text-right text-[11px] text-secondary tabular-nums">{Math.round(app.volume * 100)}%</span>
        </li>
      ))}
    </ul>
  )
}

/**
 * `speaker.wave.2.fill` ⇄ `speaker.slash.fill` with the SF Symbols replace transition the
 * app gets from `.contentTransition(.symbolEffect(.replace))`: the speaker stays put, the
 * waves shrink into it and fade, and the slash draws itself across. CSS transitions (not
 * keyframes) so a quick double click reverses mid-way instead of restarting.
 */
function MuteSymbol({ muted }: { muted: boolean }) {
  const ease = 'duration-300 ease-snappy motion-reduce:duration-150'
  return (
    <svg viewBox="0 0 16 16" className="size-[15px] flex-none" aria-hidden="true">
      <path d="M1.5 6.2c0-.4.3-.7.7-.7h2.2L7.3 3c.4-.3.9 0 .9.4v9.2c0 .4-.5.7-.9.4L4.4 10.5H2.2a.7.7 0 0 1-.7-.7Z" className="fill-current" />
      <g
        className={`origin-[8px_8px] fill-none stroke-current stroke-[1.4] transition-[opacity,transform] ${ease} ${
          muted ? 'scale-50 opacity-0' : ''
        }`}
        strokeLinecap="round"
      >
        <path d="M10.4 6a2.8 2.8 0 0 1 0 4" />
        <path d="M12.3 4.2a5.4 5.4 0 0 1 0 7.6" />
      </g>
      {/* knockout in the popover's glass tone so the slash reads as cut into the speaker */}
      <path
        d="M2.5 2.5 13.5 13.5"
        pathLength={1}
        strokeDasharray="1"
        className={`fill-none stroke-[rgb(40_40_44)] stroke-[3.2] transition-[stroke-dashoffset] ${ease} ${muted ? '[stroke-dashoffset:0]' : '[stroke-dashoffset:1]'}`}
        strokeLinecap="round"
      />
      <path
        d="M2.5 2.5 13.5 13.5"
        pathLength={1}
        strokeDasharray="1"
        className={`fill-none stroke-current stroke-[1.4] transition-[stroke-dashoffset] ${ease} ${muted ? '[stroke-dashoffset:0]' : '[stroke-dashoffset:1]'}`}
        strokeLinecap="round"
      />
    </svg>
  )
}
