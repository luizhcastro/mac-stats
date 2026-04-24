/* MacStats — Final Logo (Variation A: Graphite Vibrant / Liquid Glass Rings)
   Single source of truth for the chosen icon.
   Exposes <MacStatsIcon size={N} /> globally for the exporter + docs pages. */

const SQUIRCLE_PATH =
  "M512,0 C181,0 0,181 0,512 C0,843 181,1024 512,1024 C843,1024 1024,843 1024,512 C1024,181 843,0 512,0 Z";

// Namespaces keep gradient ids unique when multiple icons render on the same page
let __macStatsNonce = 0;
const nextNonce = () => `ms${++__macStatsNonce}`;

const MacStatsIcon = ({ size = 1024, flat = false, mono = false, rings = [0.74, 0.58, 0.4] }) => {
  const id = React.useMemo(nextNonce, []);
  const rim = 0.9;

  return (
    <div
      style={{
        width: size,
        height: size,
        position: "relative",
        filter: flat
          ? "none"
          : `drop-shadow(0 ${size * 0.015}px ${size * 0.03}px rgba(0,0,0,0.22)) drop-shadow(0 ${size * 0.05}px ${size * 0.1}px rgba(0,0,0,0.25))`,
      }}
    >
      <svg viewBox="0 0 1024 1024" width={size} height={size} style={{ display: "block", overflow: "visible" }}>
        <defs>
          <clipPath id={`clip-${id}`}>
            <path d={SQUIRCLE_PATH} />
          </clipPath>

          {/* Graphite base — slightly warmer top fading to near-black */}
          <linearGradient id={`base-${id}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={mono ? "#ffffff" : "#4a4f57"} />
            <stop offset="0.5" stopColor={mono ? "#ffffff" : "#2a2e35"} />
            <stop offset="1" stopColor={mono ? "#ffffff" : "#14161a"} />
          </linearGradient>

          {/* Top-left refracted light */}
          <radialGradient id={`refract-${id}`} cx="0.25" cy="0.2" r="0.9">
            <stop offset="0" stopColor="#ffffff" stopOpacity="0.55" />
            <stop offset="0.35" stopColor="#ffffff" stopOpacity="0.12" />
            <stop offset="0.75" stopColor="#ffffff" stopOpacity="0" />
          </radialGradient>

          {/* Bottom-right depth shadow */}
          <radialGradient id={`depth-${id}`} cx="0.75" cy="0.8" r="0.7">
            <stop offset="0.45" stopColor="#000" stopOpacity="0" />
            <stop offset="1" stopColor="#000" stopOpacity="0.35" />
          </radialGradient>

          {/* Rim highlight */}
          <linearGradient id={`rim-${id}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#ffffff" stopOpacity={rim} />
            <stop offset="0.08" stopColor="#ffffff" stopOpacity="0.15" />
            <stop offset="0.5" stopColor="#ffffff" stopOpacity="0" />
            <stop offset="1" stopColor="#ffffff" stopOpacity="0" />
          </linearGradient>

          {/* Ring gradients - outermost is brightest */}
          <linearGradient id={`r1-${id}`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#ffffff" />
            <stop offset="1" stopColor="#b9bec6" />
          </linearGradient>
          <linearGradient id={`r2-${id}`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#d6dae1" />
            <stop offset="1" stopColor="#7a7f87" />
          </linearGradient>
          <linearGradient id={`r3-${id}`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#a0a4ac" />
            <stop offset="1" stopColor="#515660" />
          </linearGradient>
          <linearGradient id={`spec-${id}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#fff" stopOpacity="0.9" />
            <stop offset="1" stopColor="#fff" stopOpacity="0" />
          </linearGradient>
        </defs>

        <g clipPath={`url(#clip-${id})`}>
          <path d={SQUIRCLE_PATH} fill={`url(#base-${id})`} />
          {!flat && <path d={SQUIRCLE_PATH} fill={`url(#refract-${id})`} />}

          {/* Rings */}
          {[
            { r: 310, width: 54, grad: `r1-${id}`, pct: rings[0] },
            { r: 236, width: 54, grad: `r2-${id}`, pct: rings[1] },
            { r: 162, width: 54, grad: `r3-${id}`, pct: rings[2] },
          ].map((ring, i) => {
            const C = 2 * Math.PI * ring.r;
            const visible = C * ring.pct;
            return (
              <g key={i} transform={`rotate(-90 512 512)`}>
                <circle cx="512" cy="512" r={ring.r} fill="none" stroke="rgba(0,0,0,0.22)" strokeWidth={ring.width} />
                <circle
                  cx="512"
                  cy="512"
                  r={ring.r}
                  fill="none"
                  stroke={`url(#${ring.grad})`}
                  strokeWidth={ring.width}
                  strokeLinecap="round"
                  strokeDasharray={`${visible} ${C}`}
                />
                {!flat && (
                  <circle
                    cx="512"
                    cy="512"
                    r={ring.r}
                    fill="none"
                    stroke={`url(#spec-${id})`}
                    strokeWidth={ring.width - 6}
                    strokeLinecap="round"
                    strokeDasharray={`${visible * 0.45} ${C}`}
                    opacity="0.85"
                  />
                )}
              </g>
            );
          })}

          {/* Central glass bead */}
          <circle cx="512" cy="512" r="70" fill="rgba(255,255,255,0.12)" />
          <circle cx="512" cy="512" r="70" fill="none" stroke="rgba(255,255,255,0.35)" strokeWidth="2" />
          {!flat && <circle cx="490" cy="490" r="20" fill="rgba(255,255,255,0.5)" />}

          {!flat && <path d={SQUIRCLE_PATH} fill={`url(#depth-${id})`} />}
        </g>

        {!flat && <path d={SQUIRCLE_PATH} fill="none" stroke={`url(#rim-${id})`} strokeWidth="4" />}
        <path d={SQUIRCLE_PATH} fill="none" stroke="rgba(0,0,0,0.4)" strokeWidth="1.5" />
      </svg>
    </div>
  );
};

window.MacStatsIcon = MacStatsIcon;
