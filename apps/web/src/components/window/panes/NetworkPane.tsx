import { INTERFACES, PUBLIC_IP, WIFI, type NetworkInterface } from '../../../data/system'
import type { LiveStats } from '../../../hooks/useLiveStats'
import { SYSTEM_COLORS } from '../../../lib/colors'
import { formatGB, formatRate } from '../../../lib/format'
import { historyFor, niceMax, type HistoryRange } from '../../../lib/history'
import { AreaChart } from '../../charts/AreaChart'
import { Icon } from '../../Icon'
import { LabeledRate, LeaderList, MetricCard, Pane, PaneHeader, RangePicker, StatRow, Value, rangeLabel } from '../PaneKit'

type NetworkPaneProps = { stats: LiveStats; range: HistoryRange; onRangeChange: (range: HistoryRange) => void }

export function NetworkPane({ stats, range, onRangeChange }: NetworkPaneProps) {
  const down = historyFor(stats, 'netIn', range)
  const up = historyFor(stats, 'netOut', range)

  return (
    <Pane>
      <PaneHeader title="Network" subtitle={`History range: ${rangeLabel(range)}`} trailing={<RangePicker value={range} onChange={onRangeChange} />} />

      <MetricCard title="Throughput" icon="network">
        <div className="flex gap-6">
          <LabeledRate label="Down" value={formatRate(stats.network.in)} color={SYSTEM_COLORS.blue} />
          <LabeledRate label="Up" value={formatRate(stats.network.out)} color={SYSTEM_COLORS.orange} />
        </div>
        <AreaChart
          filled={false}
          height={160}
          max={niceMax([...down, ...up], 0.064)}
          series={[
            { values: down, color: SYSTEM_COLORS.blue },
            { values: up, color: SYSTEM_COLORS.orange },
          ]}
        />
      </MetricCard>

      <MetricCard title="Wi-Fi" icon="wifi">
        <WiFiInfo />
      </MetricCard>

      <MetricCard title={`Interfaces (${INTERFACES.length})`} icon="network">
        <div className="divide-y divide-white/8">
          {INTERFACES.map((iface) => (
            <InterfaceRow key={iface.bsdName} iface={iface} totalIn={stats.network.in} totalOut={stats.network.out} />
          ))}
        </div>
      </MetricCard>

      <MetricCard title="Session Totals" icon="gauge">
        <StatRow label="Total in" value={formatGB(stats.network.sessionInGB)} />
        <StatRow label="Total out" value={formatGB(stats.network.sessionOutGB)} />
        <StatRow label="Public IP" value={PUBLIC_IP} />
      </MetricCard>

      <MetricCard title="Top Network Processes" icon="list">
        <LeaderList processes={stats.processes} tab="net" />
      </MetricCard>
    </Pane>
  )
}

/** WiFiInfoView: SSID, signal bars + RSSI, then a label/value grid */
function WiFiInfo() {
  const rows = [
    ['Channel', `#${WIFI.channel} · ${WIFI.bandGHz.toFixed(1)} GHz · ${WIFI.channelWidthMHz} MHz`],
    ['Tx rate', `${WIFI.txRateMbps} Mbps`],
    ['BSSID', WIFI.bssid],
    ['MAC', WIFI.hardwareAddress],
  ]

  return (
    <div className="grid gap-2">
      <div className="flex items-baseline gap-2">
        <Value size={22}>{WIFI.ssid}</Value>
        <span className="ml-auto self-end">
          <SignalBars qualityPercent={WIFI.qualityPercent} />
        </span>
        <span className="text-xs text-secondary tabular-nums">{WIFI.rssi} dBm</span>
      </div>
      <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
        {rows.map(([label, value], i) => (
          <div key={label} className="contents">
            <span className="text-secondary">{label}</span>
            <span className={`tabular-nums ${i >= 2 ? 'text-xs leading-5' : ''}`}>{value}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function SignalBars({ qualityPercent }: { qualityPercent: number }) {
  const active = Math.max(0, Math.min(4, Math.round(qualityPercent / 25)))
  return (
    <span className="flex items-end gap-0.5" aria-label={`Signal ${active} of 4`}>
      {[0, 1, 2, 3].map((i) => (
        <span key={i} className={`w-1 rounded-[1px] ${i < active ? 'bg-[#0a84ff]' : 'bg-white/25'}`} style={{ height: 6 + i * 3 }} />
      ))}
    </span>
  )
}

type InterfaceRowProps = { iface: NetworkInterface; totalIn: number; totalOut: number }

/** InterfaceRow: status dot, name + BSD name, addresses, per-interface ↓/↑ on the right */
function InterfaceRow({ iface, totalIn, totalOut }: InterfaceRowProps) {
  return (
    <div className="flex items-start gap-2 py-2.5 first:pt-0 last:pb-0">
      <span className={`mt-1.5 size-[7px] flex-none rounded-full ${iface.isUp ? 'bg-nominal' : 'border border-secondary'}`} />
      <div className="grid min-w-0 flex-1 gap-0.5">
        <div className="flex items-baseline gap-1.5">
          <span className="text-sm font-medium">{iface.displayName}</span>
          <span className="text-xs text-tertiary tabular-nums">{iface.bsdName}</span>
        </div>
        {(iface.ipv4 || iface.ipv6) && (
          <div className="flex min-w-0 gap-2 tabular-nums">
            {iface.ipv4 && <span className="text-xs text-secondary">{iface.ipv4}</span>}
            {iface.ipv6 && <span className="truncate text-[10px] leading-4 text-tertiary">{iface.ipv6}</span>}
          </div>
        )}
      </div>
      <div className="grid justify-items-end gap-0.5 text-xs tabular-nums">
        <span className="flex items-center gap-1">
          <span style={{ color: SYSTEM_COLORS.blue }}>
            <Icon name="arrowDown" className="size-2.5" />
          </span>
          {formatRate(totalIn * iface.share)}
        </span>
        <span className="flex items-center gap-1">
          <span style={{ color: SYSTEM_COLORS.orange }}>
            <Icon name="arrowUp" className="size-2.5" />
          </span>
          {formatRate(totalOut * iface.share)}
        </span>
      </div>
    </div>
  )
}
