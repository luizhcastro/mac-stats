/** Baseline numbers for the fake process list. Live values jitter around these. */
export type Process = {
  pid: number
  name: string
  /** % of one core */
  cpu: number
  memoryGB: number
  /** MB/s */
  diskRead: number
  diskWrite: number
  netIn: number
  netOut: number
  /** Energy impact, as in Activity Monitor */
  energy: number
}

export const BASE_PROCESSES: Process[] = [
  { pid: 812, name: 'Xcode', cpu: 38.4, memoryGB: 3.4, diskRead: 1.0, diskWrite: 0.4, netIn: 0.006, netOut: 0.002, energy: 42.1 },
  { pid: 371, name: 'WindowServer', cpu: 14.2, memoryGB: 0.6, diskRead: 0, diskWrite: 0, netIn: 0, netOut: 0, energy: 9.6 },
  { pid: 1204, name: 'Google Chrome', cpu: 9.1, memoryGB: 2.1, diskRead: 0.2, diskWrite: 0.1, netIn: 1.0, netOut: 0.1, energy: 18.3 },
  { pid: 1477, name: 'Slack', cpu: 4.3, memoryGB: 0.9, diskRead: 0.06, diskWrite: 0.04, netIn: 0.15, netOut: 0.05, energy: 5.2 },
  { pid: 1532, name: 'Spotify', cpu: 2.2, memoryGB: 0.4, diskRead: 0.02, diskWrite: 0.01, netIn: 0.09, netOut: 0.01, energy: 3.1 },
  { pid: 298, name: 'mds_stores', cpu: 1.8, memoryGB: 0.12, diskRead: 2.4, diskWrite: 0.8, netIn: 0, netOut: 0, energy: 1.1 },
  { pid: 541, name: 'Finder', cpu: 0.9, memoryGB: 0.3, diskRead: 0.01, diskWrite: 0.01, netIn: 0, netOut: 0, energy: 0.6 },
  { pid: 2210, name: 'MacStats', cpu: 0.5, memoryGB: 0.076, diskRead: 0, diskWrite: 0, netIn: 0, netOut: 0, energy: 0.3 },
  { pid: 1650, name: 'Photos', cpu: 0.4, memoryGB: 0.5, diskRead: 0.4, diskWrite: 0.2, netIn: 0.003, netOut: 0.001, energy: 1.4 },
  { pid: 1712, name: 'Mail', cpu: 0.3, memoryGB: 0.2, diskRead: 0.03, diskWrite: 0.02, netIn: 0.015, netOut: 0.005, energy: 0.5 },
  { pid: 402, name: 'backupd', cpu: 0.3, memoryGB: 0.05, diskRead: 0.15, diskWrite: 0.05, netIn: 0, netOut: 0, energy: 0.4 },
  { pid: 455, name: 'cloudd', cpu: 0.2, memoryGB: 0.04, diskRead: 0.01, diskWrite: 0, netIn: 0.008, netOut: 0.002, energy: 0.2 },
  { pid: 389, name: 'softwareupdated', cpu: 0.1, memoryGB: 0.03, diskRead: 0, diskWrite: 0, netIn: 0.03, netOut: 0.01, energy: 0.1 },
  { pid: 467, name: 'nsurlsessiond', cpu: 0.1, memoryGB: 0.02, diskRead: 0, diskWrite: 0, netIn: 0.003, netOut: 0.001, energy: 0.1 },
  { pid: 1, name: 'launchd', cpu: 0.1, memoryGB: 0.02, diskRead: 0, diskWrite: 0, netIn: 0, netOut: 0, energy: 0.1 },
  { pid: 0, name: 'kernel_task', cpu: 3.6, memoryGB: 1.1, diskRead: 0.05, diskWrite: 0.05, netIn: 0, netOut: 0, energy: 2.4 },
]
