import { useState, type ReactNode } from 'react'
import type { LiveStats } from '../../hooks/useLiveStats'
import type { HistoryRange } from '../../lib/history'
import { MAIN_WINDOW_ID } from '../../lib/links'
import type { BarMetric } from '../../lib/metrics'
import type { Mixer } from '../../lib/mixer'
import { order } from '../../lib/motion'
import { TrafficLights } from '../TrafficLights'
import { BatteryPane } from './panes/BatteryPane'
import { CpuPane } from './panes/CpuPane'
import { DiskPane } from './panes/DiskPane'
import { FansPane } from './panes/FansPane'
import { GpuPane } from './panes/GpuPane'
import { MemoryPane } from './panes/MemoryPane'
import { NetworkPane } from './panes/NetworkPane'
import { OverviewPane } from './panes/OverviewPane'
import { ProcessesPane } from './panes/ProcessesPane'
import { SettingsPane } from './panes/SettingsPane'
import { SoundPane } from './panes/SoundPane'
import { TemperaturePane } from './panes/TemperaturePane'
import { CompactSidebar, SECTION_TITLES, Sidebar, type SidebarSection } from './Sidebar'

type MainWindowProps = {
  stats: LiveStats
  mixer: Mixer
  visible: Set<BarMetric>
  onToggleMetric: (metric: BarMetric) => void
}

/** Interactive replica of the MacStats main window (MainWindowView.swift) */
export function MainWindow({ stats, mixer, visible, onToggleMetric }: MainWindowProps) {
  const [selection, setSelection] = useState<SidebarSection>('overview')
  const [range, setRange] = useState<HistoryRange>('minute')

  const rangeProps = { stats, range, onRangeChange: setRange }
  const panes: Record<SidebarSection, ReactNode> = {
    overview: <OverviewPane stats={stats} />,
    cpu: <CpuPane {...rangeProps} />,
    gpu: <GpuPane stats={stats} />,
    memory: <MemoryPane {...rangeProps} />,
    disk: <DiskPane {...rangeProps} />,
    network: <NetworkPane {...rangeProps} />,
    battery: <BatteryPane />,
    temperature: <TemperaturePane {...rangeProps} />,
    fans: <FansPane stats={stats} />,
    processes: <ProcessesPane stats={stats} />,
    sound: <SoundPane mixer={mixer} />,
    settings: <SettingsPane visible={visible} onToggleMetric={onToggleMetric} />,
  }

  return (
    <section id={MAIN_WINDOW_ID} aria-labelledby="main-window-title" className="scroll-mt-16 pt-[clamp(6rem,12vw,11rem)]" style={order(0)}>
      <div className="page">
        <h2 id="main-window-title" className="enter text-head leading-none font-bold tracking-[-0.035em]">
          The whole machine in one window
        </h2>
        <p className="enter mt-6 max-w-[34em] text-lead leading-snug">
          CPU, GPU, memory, disk, network, battery, temperature and fans each get a pane, plus a process table you can
          filter and sort. This one is live too.
        </p>
      </div>

      {/* The window sits on the same grey stage as the dropdown, bleeding off the right edge */}
      <div className="enter mt-14 ml-[max(0px,calc((100vw-1280px)/2))] rounded-tl-[160px] bg-stage py-[clamp(1.25rem,5vw,5rem)] pr-[clamp(1.25rem,4vw,3rem)] pl-[clamp(1.25rem,6vw,6rem)] max-md:rounded-tl-[72px] max-md:px-3">
        <div
          data-ui
          aria-label="MacStats main window preview"
          className="glass glass-dark flex h-[min(720px,85svh)] max-w-[1180px] overflow-hidden rounded-[26px] p-2 text-label max-md:h-auto max-md:flex-col max-md:p-0"
        >
          <Sidebar selection={selection} onSelect={setSelection} />

          <div className="flex min-w-0 flex-1 flex-col">
            <div className="flex h-11 flex-none items-center gap-3 px-6 max-md:px-4">
              <span className="md:hidden">
                <TrafficLights />
              </span>
              <span className="text-[15px] font-semibold">{SECTION_TITLES[selection]}</span>
            </div>
            <CompactSidebar selection={selection} onSelect={setSelection} />
            <div className="min-h-0 flex-1 md:overflow-y-auto">{panes[selection]}</div>
          </div>
        </div>
      </div>
    </section>
  )
}
