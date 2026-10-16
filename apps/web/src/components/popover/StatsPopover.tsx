import { useLayoutEffect, useRef } from 'react'
import type { PopoverPosition } from '../../hooks/usePopoverAnchor'
import type { LiveStats } from '../../hooks/useLiveStats'
import { formatRate } from '../../lib/format'
import { MAIN_WINDOW_ID } from '../../lib/links'
import type { BarMetric, ProcessTab } from '../../lib/metrics'
import type { Mixer } from '../../lib/mixer'
import { Icon } from '../Icon'
import { MixerRows } from './MixerRows'
import { Caption, Divider, InOutRow, Section } from './Section'
import { Sparkline } from './Sparkline'
import { TopProcesses } from './TopProcesses'

type StatsPopoverProps = {
  stats: LiveStats
  mixer: Mixer
  /** Where to float under the menu bar; null = sit in the page flow (narrow screens) */
  position: PopoverPosition | null
  /** Menu bar item it's anchored to; changing it replays the open animation from the new arrow */
  anchor: BarMetric
  tab: ProcessTab
  onTabChange: (tab: ProcessTab) => void
}

/**
 * The dropdown, section by section in the same order as MenuBarContentView.swift. Sections
 * collapse from their header like the app's; CPU and Top processes start open. Sound starts
 * open here too (collapsed in the app) so the mixer is visible on the page.
 */
export function StatsPopover({ stats, mixer, position, anchor, tab, onTabChange }: StatsPopoverProps) {
  const { cpu, memory, temperature } = stats
  const [load1, load5, load15] = cpu.load
  const playing = mixer.apps.filter((a) => a.playing).length

  // NSPopover grows out of its arrow: replay that whenever it re-anchors under another item
  const ref = useRef<HTMLDivElement>(null)
  const firstAnchor = useRef(true)
  useLayoutEffect(() => {
    if (firstAnchor.current) {
      firstAnchor.current = false
      return
    }
    const el = ref.current
    if (!el || !position) return
    el.classList.remove('popover-enter', 'animate-popover-in')
    void el.offsetWidth // restart the animation
    el.classList.add('animate-popover-in')
  }, [anchor])

  return (
    <div
      ref={ref}
      data-ui
      aria-label="MacStats dropdown preview"
      style={position ? { left: position.left, transformOrigin: `${position.arrow}px 0` } : undefined}
      className={`popover-enter glass glass-dark w-[min(340px,100%)] rounded-[22px] p-3.5 text-[13px] leading-[1.3] ${
        position ? 'absolute top-[38px] z-20' : 'relative mx-auto'
      }`}
    >
      <PopoverArrow left={position?.arrow} />

      <header className="flex items-center gap-2">
        <img src="/icon.png" alt="" className="size-8" />
        <div className="flex-1">
          <div className="font-bold">MacStats</div>
          <Caption>System monitor</Caption>
        </div>
        <a href={`#${MAIN_WINDOW_ID}`} data-umami-event="Open main window" title="Open main window" aria-label="Open main window" className="rounded p-0.5 text-secondary hover:text-label">
          <Icon name="macwindow" className="size-[15px]" />
        </a>
      </header>

      <Divider />
      <Section icon="cpu" title="CPU" value={<span className="tabular-nums">{cpu.total.toFixed(0)}%</span>} defaultOpen>
        <Caption>
          user {cpu.user.toFixed(0)}%&ensp;sys {cpu.system.toFixed(0)}%&ensp;idle {(100 - cpu.total).toFixed(0)}%
        </Caption>
        <Caption>
          load {load1.toFixed(2)} / {load5.toFixed(2)} / {load15.toFixed(2)}
        </Caption>
        <Sparkline values={stats.history.cpu} max={50} />
      </Section>

      <Divider />
      <Section icon="thermometer" title="Temperature" value={<span className="tabular-nums">{temperature.cpu.toFixed(0)}°C</span>}>
        <Caption className="flex justify-between">
          <span>Max {temperature.max.toFixed(0)}°C</span>
          <span className="text-nominal">· Nominal</span>
        </Caption>
      </Section>

      <Divider />
      <Section
        icon="memorychip"
        title="Memory"
        value={<span className="tabular-nums">{memory.usedGB.toFixed(1)} GB / {memory.totalGB} GB</span>}
      >
        <Caption>
          wired {memory.wiredGB.toFixed(1)} GB&ensp;comp {memory.compressedGB.toFixed(1)} GB
        </Caption>
        <div className="mt-1.5 h-[7px] overflow-hidden rounded bg-white/8">
          <div
            className="h-full rounded bg-accent transition-[width] duration-600 motion-reduce:transition-none"
            style={{ width: `${memory.pressure}%` }}
          />
        </div>
      </Section>

      <Divider />
      <Section
        icon="network"
        title="Network"
        value={
          <span className="font-normal">
            <InOutRow down={formatRate(stats.network.in)} up={formatRate(stats.network.out)} />
          </span>
        }
      />

      <Divider />
      <Section icon="internaldrive" title="Disk" value={<span className="tabular-nums">412 GB / 494 GB</span>}>
        <InOutRow down={formatRate(stats.disk.read)} up={formatRate(stats.disk.write)} />
      </Section>

      <Divider />
      <Section icon="battery" title="Battery" value="87%">
        <Caption>5h 12m remaining</Caption>
        <Caption>212 cycles · 96% health</Caption>
      </Section>

      <Divider />
      <Section
        icon="speaker"
        title="Sound"
        value={<Caption>{playing === 0 ? 'silent' : `${playing} playing`}</Caption>}
        defaultOpen
      >
        <MixerRows mixer={mixer} compact />
      </Section>

      <Divider />
      <Section icon="list" title="Top processes" defaultOpen>
        <TopProcesses tab={tab} onTabChange={onTabChange} processes={stats.processes} />
      </Section>

      <Divider />
      <div className="text-right text-secondary">Quit</div>
    </div>
  )
}

/** The little nub pointing at the menu bar item, in the same glass as the body */
function PopoverArrow({ left }: { left?: number }) {
  return (
    <span
      aria-hidden="true"
      className="absolute -top-2.5 h-[11px] w-7 bg-[rgb(78_78_84/0.9)] backdrop-blur-[28px]"
      style={{
        left: left === undefined ? 'calc(50% - 14px)' : left - 14,
        clipPath: 'path("M0 11 C6 11 9 9 11.5 3 Q14 -1 16.5 3 C19 9 22 11 28 11 Z")',
      }}
    />
  )
}
