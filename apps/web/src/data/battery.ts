/** The battery barely moves within a page visit, so it's static */
export const BATTERY = {
  percent: 87,
  isCharging: false,
  isPluggedIn: false,
  /** "On battery" / "Charging" / "Plugged in", like BatteryPane.status */
  state: 'On battery',
  timeRemaining: '5h 12m',
  watts: -6.4,
  cycles: 212,
  healthPercent: 96,
  fullChargeMAh: 4207,
  designCapacityMAh: 4382,
  voltage: 12.45,
  amperageMA: -514,
  temperature: 31.2,
  deviceName: 'bq40z651',
  serial: 'F8Y3216XQ4K1P7RAX',
  /** Last 30 minutes, one sample per 30 s: a slow, steady discharge */
  chargeHistory: Array.from({ length: 60 }, (_, i) => 93 - i * 0.1),
  /** Signed watts, negative = discharging */
  powerHistory: Array.from({ length: 60 }, (_, i) => -6 - Math.sin(i / 4) * 1.5 - (i % 7 === 0 ? 3 : 0)),
}
