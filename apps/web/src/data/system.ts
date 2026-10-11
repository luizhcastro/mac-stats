/** Static hardware details shown in the window panes (things that don't change second to second) */

export const GPU_NAME = 'Apple M-series GPU'

export const WIFI = {
  ssid: 'Home',
  rssi: -54,
  qualityPercent: 78,
  channel: 149,
  bandGHz: 5,
  channelWidthMHz: 80,
  txRateMbps: 866,
  bssid: 'a4:2b:b0:1c:7e:12',
  hardwareAddress: '3c:22:fb:9a:41:0d',
}

export const PUBLIC_IP = '203.0.113.42'

export type NetworkInterface = {
  displayName: string
  bsdName: string
  ipv4?: string
  ipv6?: string
  isUp: boolean
  /** Share of the total traffic this interface carries */
  share: number
}

export const INTERFACES: NetworkInterface[] = [
  { displayName: 'Wi-Fi', bsdName: 'en0', ipv4: '192.168.1.24', ipv6: 'fe80::1c8a:4f2e:9b3d:7a10', isUp: true, share: 0.97 },
  { displayName: 'VPN', bsdName: 'utun3', ipv4: '10.8.0.2', isUp: true, share: 0.03 },
  { displayName: 'Thunderbolt Ethernet', bsdName: 'en5', isUp: false, share: 0 },
]

export type Volume = {
  displayName: string
  bsdName: string
  mountPath: string
  usedGB: number
  totalGB: number
  isInternal: boolean
  isReadOnly: boolean
  smart: 'healthy' | 'unsupported'
}

export const VOLUMES: Volume[] = [
  { displayName: 'Macintosh HD', bsdName: 'disk3s1s1', mountPath: '/', usedGB: 412.4, totalGB: 494.4, isInternal: true, isReadOnly: true, smart: 'healthy' },
  { displayName: 'Data', bsdName: 'disk3s5', mountPath: '/System/Volumes/Data', usedGB: 412.4, totalGB: 494.4, isInternal: true, isReadOnly: false, smart: 'healthy' },
  { displayName: 'Backup', bsdName: 'disk5s2', mountPath: '/Volumes/Backup', usedGB: 610.2, totalGB: 1000, isInternal: false, isReadOnly: false, smart: 'unsupported' },
]
