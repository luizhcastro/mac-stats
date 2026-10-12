import { useState } from 'react'

/** One row of the volume mixer, mirrors `MixerApp` in AudioMixer.swift */
export type MixerApp = {
  id: string
  name: string
  /** App icon in public/apps, rendered from the real app with NSWorkspace like the mixer does */
  icon: string
  playing: boolean
  /** 0–1 */
  volume: number
  muted: boolean
}

// Like the app: rows for apps with an audio session, the ones playing first
const INITIAL: MixerApp[] = [
  { id: 'spotify', name: 'Spotify', icon: '/apps/spotify.png', playing: true, volume: 0.45, muted: false },
  { id: 'chrome', name: 'Google Chrome', icon: '/apps/chrome.png', playing: true, volume: 1, muted: false },
  { id: 'discord', name: 'Discord', icon: '/apps/discord.png', playing: false, volume: 1, muted: false },
  { id: 'music', name: 'Music', icon: '/apps/music.png', playing: false, volume: 1, muted: false },
  { id: 'whatsapp', name: 'WhatsApp', icon: '/apps/whatsapp.png', playing: false, volume: 0.8, muted: true },
]

export type Mixer = {
  apps: MixerApp[]
  setVolume: (id: string, volume: number) => void
  toggleMute: (id: string) => void
}

/** Shared by the dropdown's Sound section and the Sound pane, so both stay in sync */
export function useMixer(): Mixer {
  const [apps, setApps] = useState(INITIAL)
  const update = (id: string, change: Partial<MixerApp>) =>
    setApps((current) => current.map((app) => (app.id === id ? { ...app, ...change } : app)))

  return {
    apps,
    setVolume: (id, volume) => update(id, { volume }),
    toggleMute: (id) => update(id, { muted: !apps.find((a) => a.id === id)!.muted }),
  }
}
