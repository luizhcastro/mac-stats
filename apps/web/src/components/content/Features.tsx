import { useState, type ReactNode } from 'react'
import type { LiveStats } from '../../hooks/useLiveStats'
import { SYSTEM_COLORS } from '../../lib/colors'
import { formatPercent } from '../../lib/format'
import { historyFor, type HistoryRange } from '../../lib/history'
import type { BarMetric, ProcessTab } from '../../lib/metrics'
import type { Mixer } from '../../lib/mixer'
import { AreaChart } from '../charts/AreaChart'
import { Icon, type IconName } from '../Icon'
import { StatusItems } from '../menubar/MenuBar'
import { MenuBarPrefs } from '../popover/MenuBarPrefs'
import { MixerRows } from '../popover/MixerRows'
import { Caption } from '../popover/Section'
import { TopProcesses } from '../popover/TopProcesses'
import { RangePicker } from '../window/PaneKit'

type FeaturesProps = {
  stats: LiveStats
  mixer: Mixer
  visible: Set<BarMetric>
  onToggleMetric: (metric: BarMetric) => void
}

/**
 * A bento of capabilities: each is a small working piece of the app with what it does under
 * it. Three across on wide screens, history spanning two. The pieces share state with the
 * replicas above (menu bar items, mixer volumes). Their section headers are fixed, not the
 * dropdown's collapsible ones: folding one would resize every panel in its row.
 */
export function Features({ stats, mixer, visible, onToggleMetric }: FeaturesProps) {
  const [tab, setTab] = useState<ProcessTab>('ram')
  const [range, setRange] = useState<HistoryRange>('hour')
  const [shareStats, setShareStats] = useState(true)
  const playing = mixer.apps.filter((a) => a.playing).length

  return (
    <section id="features" aria-labelledby="features-title" className="page scroll-mt-16 pt-[clamp(6rem,14vw,12rem)]">
      <h2 id="features-title" className="enter text-head leading-none font-bold tracking-[-0.035em]">
        What you get
      </h2>

      {/* Each feature spans two rows of a subgrid (panel, then text), so the panels in a row share
          one height and the titles under them share one baseline, whatever their content */}
      <div className="mt-16 grid grid-flow-dense gap-x-5 gap-y-14 md:grid-cols-2 lg:grid-cols-3">
        <Feature
          icon="menubar"
          label="Menu bar"
          title="Pick what sits in the bar"
          fragment={
            <div className="grid gap-4">
              <div className="flex h-[30px] items-center justify-end overflow-hidden rounded-md bg-white/8 px-2 text-[13px]">
                <StatusItems stats={stats} visible={visible} />
              </div>
              <MenuBarPrefs visible={visible} onToggle={onToggleMetric} />
            </div>
          }
        >
          Each metric is its own menu bar item, so a crowded bar hides them one at a time. Untick one here and watch the
          bar at the top.
        </Feature>

        <Feature
          icon="list"
          label="Top processes"
          title="See which app is using it"
          fragment={<TopProcesses tab={tab} onTabChange={setTab} processes={stats.processes} />}
        >
          Top processes by CPU, memory, disk, network and energy. The dropdown opens on the tab of the item you clicked.
        </Feature>

        <Feature
          icon="speaker"
          label="Sound"
          value={<Caption>{playing === 0 ? 'silent' : `${playing} playing`}</Caption>}
          title="A volume slider for every app"
          fragment={<MixerRows mixer={mixer} compact />}
        >
          Each app that plays sound gets its own slider and mute, remembered for next time. Needs macOS 14.4.
        </Feature>

        <Feature
          wide
          icon="cpu"
          label="CPU"
          value={
            <span className="flex items-center gap-3">
              <span className="tabular-nums">{formatPercent(stats.cpu.total)}</span>
              <RangePicker value={range} onChange={setRange} />
            </span>
          }
          title="The last minute, hour or day"
          fragment={<AreaChart series={[{ values: historyFor(stats, 'cpu', range), color: SYSTEM_COLORS.blue }]} max={100} height={150} />}
        >
          Charts in the main window switch between the last minute, hour and day, so you can see what spiked while you
          were away.
        </Feature>

        <Feature
          icon="gear"
          label="Privacy"
          title="No account, no ads"
          fragment={
            <div className="grid gap-2">
              <label className="flex cursor-pointer items-center justify-between gap-4">
                Share anonymous usage statistics
                <input type="checkbox" checked={shareStats} onChange={(e) => setShareStats(e.target.checked)} className="peer sr-only" />
                <span
                  aria-hidden="true"
                  className="relative h-[22px] w-[38px] flex-none rounded-full bg-white/15 transition-colors duration-300 ease-snappy peer-checked:bg-[#30d158] peer-focus-visible:outline-3 peer-focus-visible:outline-white/60 after:absolute after:top-0.5 after:left-0.5 after:size-[18px] after:rounded-full after:bg-white after:transition-transform after:duration-300 after:ease-snappy peer-checked:after:translate-x-4 motion-reduce:after:transition-none"
                />
              </label>
              {/* SettingsPane.swift's caption */}
              <p className="text-xs leading-snug text-secondary">
                At most three pings a day with the app version, macOS version, CPU architecture and a random install ID. No
                system metrics, processes or personal data.
              </p>
            </div>
          }
        >
          Free and MIT licensed. At most three anonymous usage pings a day, and one switch in Settings turns them off.
        </Feature>
      </div>
    </section>
  )
}

type FeatureProps = {
  /** The panel's header, like the app's own section headers */
  icon: IconName
  label: string
  value?: ReactNode
  fragment: ReactNode
  /** The text under the panel */
  title: string
  children: ReactNode
  wide?: boolean
}

function Feature({ icon, label, value, fragment, title, children, wide = false }: FeatureProps) {
  return (
    <article className={`row-span-2 grid grid-rows-subgrid gap-y-6 ${wide ? 'md:col-span-2' : ''}`}>
      <div data-ui className="enter rounded-2xl bg-surface p-5 text-[13px] leading-[1.3] text-label">
        <div className="flex h-6 items-center gap-2 font-semibold">
          <Icon name={icon} className="size-[15px]" />
          <span className="flex-1">{label}</span>
          {value}
        </div>
        <div className="mt-3">{fragment}</div>
      </div>
      <div className="enter late max-w-[34em]">
        <h3 className="text-lead leading-tight font-semibold tracking-[-0.015em]">{title}</h3>
        <p className="mt-2">{children}</p>
      </div>
    </article>
  )
}
