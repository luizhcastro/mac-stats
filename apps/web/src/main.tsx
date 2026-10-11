import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'
import { loadAnalytics } from './lib/analytics'
import './index.css'

loadAnalytics()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
