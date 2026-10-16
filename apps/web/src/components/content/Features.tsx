import { useState, type ReactNode } from 'react'
import type { LiveStats } from '../../hooks/useLiveStats'
import { SYSTEM_COLORS } from '../../lib/colors'
import { formatPercent } from '../../lib/format'
import { historyFor, type HistoryRange } from '../../lib/history'
import type { BarMetric, ProcessTab } from '../../lib/metrics'
import type { Mixer } from '../../lib/mixer'
import { AreaChart } from '../charts/AreaChart'
import { StatusItems } from '../menubar/MenuBar'
import { MenuBarPrefs } from '../popover/MenuBarPrefs'
import { MixerRows } from '../popover/MixerRows'
import { Caption, Section } from '../popover/Section'
import { TopProcesses } from '../popover/TopProcesses'
import { RangePicker, Value } from '../window/PaneKit'

type FeaturesProps = {
  stats: LiveStats
  mixer: Mixer
  visible: Set<BarMetric>
  onToggleMetric: (metric: BarMetric) => void
}

/**
 * One capability per row: a small working piece of the app on the left, what it does on the
 * right. The pieces share state with the replicas above (menu bar items, mixer volumes).
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

      <div className="mt-16 grid gap-[clamp(4rem,9vw,7.5rem)] lg:pl-[12%]">
        <Feature
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
          <p>
            CPU, temperature, RAM, disk and network are separate menu bar items, so a crowded bar hides them one at a time
            instead of all at once.
          </p>
          <p>Untick one here and watch the bar at the top of this page.</p>
        </Feature>

        <Feature
          title="See which app is using it"
          fragment={
            <Section icon="list" title="Top processes" defaultOpen>
              <TopProcesses tab={tab} onTabChange={setTab} processes={stats.processes} />
            </Section>
          }
        >
          <p>
            The dropdown lists the top processes by CPU, memory, disk, network and energy, and opens on the tab of the item
            you clicked.
          </p>
          <p>Every section folds away, so it stays as short as you like.</p>
        </Feature>

        <Feature
          title="A volume slider for every app"
          fragment={
            <Section icon="speaker" title="Sound" value={<Caption>{playing === 0 ? 'silent' : `${playing} playing`}</Caption>} defaultOpen>
              <MixerRows mixer={mixer} compact />
            </Section>
          }
        >
          <p>
            Each app that plays sound gets its own slider and mute, like the Windows mixer. MacStats remembers the level
            and applies it the next time the app plays.
          </p>
          <p>Needs macOS 14.4 or later.</p>
        </Feature>

        <Feature
          title="The last minute, hour or day"
          fragment={
            <div className="grid gap-3">
              <div className="flex items-center justify-between gap-4">
                <Value size={24}>{formatPercent(stats.cpu.total)}</Value>
                <RangePicker value={range} onChange={setRange} />
              </div>
              <AreaChart series={[{ values: historyFor(stats, 'cpu', range), color: SYSTEM_COLORS.blue }]} max={100} height={150} />
            </div>
          }
        >
          <p>
            Charts in the main window switch between the last minute, hour and day, so you can see what spiked while you
            were away.
          </p>
          <p>CPU, memory, network, disk and temperature all keep their history.</p>
        </Feature>

        <Feature
          title="No account, no ads"
          fragment={
            <label className="flex cursor-pointer items-center justify-between gap-4 text-[13px]">
              Share anonymous usage statistics
              <input type="checkbox" checked={shareStats} onChange={(e) => setShareStats(e.target.checked)} className="peer sr-only" />
              <span
                aria-hidden="true"
                className="relative h-[22px] w-[38px] flex-none rounded-full bg-white/15 transition-colors duration-300 ease-snappy peer-checked:bg-[#30d158] peer-focus-visible:outline-3 peer-focus-visible:outline-white/60 after:absolute after:top-0.5 after:left-0.5 after:size-[18px] after:rounded-full after:bg-white after:transition-transform after:duration-300 after:ease-snappy peer-checked:after:translate-x-4 motion-reduce:after:transition-none"
              />
            </label>
          }
        >
          <p>MacStats is free and MIT licensed. Updates come through Sparkle, straight from the GitHub releases.</p>
          <p>It sends at most three anonymous usage pings a day. One switch in Settings turns them off.</p>
        </Feature>
      </div>
    </section>
  )
}

type FeatureProps = { title: string; fragment: ReactNode; children: ReactNode }

function Feature({ title, fragment, children }: FeatureProps) {
  return (
    <article className="grid max-w-[25rem] items-start lg:max-w-none gap-x-10 gap-y-6 lg:grid-cols-[minmax(0,25rem)_minmax(0,22rem)]">
      <div data-ui className="enter rounded-2xl bg-surface p-5 text-[13px] leading-[1.3] text-label">
        {fragment}
      </div>
      <div className="enter late">
        <h3 className="text-lead leading-tight font-semibold tracking-[-0.015em]">{title}</h3>
        <div className="mt-3 grid gap-3">{children}</div>
      </div>
    </article>
  )
}
