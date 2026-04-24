/* MacStats — Final Icon Showcase (Variation A only)
   Shows the final icon at multiple sizes, in Dock context, and as favicon/menubar. */

const App = () => (
  <DesignCanvas
    title="MacStats — Final App Icon"
    subtitle="Graphite Vibrant · Liquid Glass · three concentric activity rings"
  >
    <DCSection id="hero" title="Hero" subtitle="1024×1024 marketing / App Store">
      <DCArtboard id="hero-1024" label="1024 / hero" width={1280} height={1280}>
        <div style={{
          width: "100%", height: "100%",
          background: "linear-gradient(180deg,#f6f7f9 0%,#e4e7ed 100%)",
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          <MacStatsIcon size={960} />
        </div>
      </DCArtboard>

      <DCArtboard id="hero-wall" label="1024 / over wallpaper" width={1280} height={1280}>
        <div style={{
          width: "100%", height: "100%",
          background: "linear-gradient(135deg, #4a6fb8 0%, #8b5ec7 40%, #d96e8a 75%, #f0a070 100%)",
          display: "flex", alignItems: "center", justifyContent: "center",
          position: "relative", overflow: "hidden",
        }}>
          <div style={{
            position: "absolute", top: "-10%", left: "-10%", width: "70%", height: "70%",
            background: "radial-gradient(circle, rgba(255,200,100,0.6), transparent 70%)",
            filter: "blur(50px)",
          }} />
          <div style={{
            position: "absolute", bottom: "-10%", right: "-10%", width: "70%", height: "70%",
            background: "radial-gradient(circle, rgba(80,120,255,0.55), transparent 70%)",
            filter: "blur(50px)",
          }} />
          <MacStatsIcon size={960} />
        </div>
      </DCArtboard>
    </DCSection>

    <DCSection id="sizes" title="All sizes" subtitle="Every size required for a macOS .icns bundle">
      <DCArtboard id="size-grid" label="Size ladder" width={1800} height={640}>
        <div style={{
          width: "100%", height: "100%",
          background: "linear-gradient(180deg,#fafbfc 0%,#eef0f3 100%)",
          display: "flex", alignItems: "flex-end", justifyContent: "space-around",
          padding: 60, boxSizing: "border-box",
          fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif",
        }}>
          {[512, 256, 128, 64, 32, 16].map(s => (
            <div key={s} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
              <MacStatsIcon size={s} />
              <div style={{
                fontFamily: "ui-monospace,'SF Mono',Menlo,monospace",
                fontSize: 11, color: "#7a7e85", letterSpacing: 0.4, textTransform: "uppercase",
              }}>
                {s}px
              </div>
            </div>
          ))}
        </div>
      </DCArtboard>
    </DCSection>

    <DCSection id="context" title="In context" subtitle="macOS Dock · Finder list · menu bar">
      <DCArtboard id="dock" label="Dock (Tahoe-style)" width={1600} height={380}>
        <div style={{
          width: "100%", height: "100%",
          background: "linear-gradient(135deg, #4a6fb8 0%, #8b5ec7 40%, #d96e8a 75%, #f0a070 100%)",
          display: "flex", alignItems: "center", justifyContent: "center",
          position: "relative", overflow: "hidden",
        }}>
          <div style={{
            background: "rgba(255,255,255,0.18)",
            backdropFilter: "blur(30px) saturate(180%)",
            WebkitBackdropFilter: "blur(30px) saturate(180%)",
            border: "1px solid rgba(255,255,255,0.35)",
            borderRadius: 40,
            padding: "18px 26px",
            boxShadow: "0 16px 50px rgba(0,0,0,0.25), inset 0 1px 0 rgba(255,255,255,0.6)",
            display: "flex", alignItems: "center", gap: 16,
          }}>
            <div style={{ width: 128, height: 128, background: "linear-gradient(180deg,#5a8df0,#2c5fd0)", borderRadius: 28, opacity: 0.8 }} />
            <div style={{ width: 128, height: 128, background: "linear-gradient(180deg,#48b56a,#268040)", borderRadius: 28, opacity: 0.8 }} />
            <div style={{ width: 128, height: 128, background: "linear-gradient(180deg,#fbb040,#e08020)", borderRadius: 28, opacity: 0.8 }} />
            <MacStatsIcon size={128} />
            <div style={{ width: 128, height: 128, background: "linear-gradient(180deg,#e85e8a,#b03060)", borderRadius: 28, opacity: 0.8 }} />
            <div style={{ width: 128, height: 128, background: "linear-gradient(180deg,#8e8e93,#5a5a5f)", borderRadius: 28, opacity: 0.8 }} />
          </div>
        </div>
      </DCArtboard>

      <DCArtboard id="finder" label="Finder list" width={900} height={420}>
        <div style={{
          width: "100%", height: "100%",
          background: "#fbfbfd",
          padding: "20px 28px",
          fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
          color: "#1a1c1f",
          fontSize: 15,
          boxSizing: "border-box",
        }}>
          {[
            { name: "iStat Menus", color: "linear-gradient(180deg,#5e9eff,#2560cc)" },
            { name: "MacStats", isIcon: true },
            { name: "Monit", color: "linear-gradient(180deg,#ff8a4c,#d94c18)" },
            { name: "Stats", color: "linear-gradient(180deg,#8b6fe8,#5a3fc4)" },
            { name: "Sensei", color: "linear-gradient(180deg,#48b56a,#268040)" },
          ].map((app, i) => (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 12,
              padding: "8px 8px",
              background: app.name === "MacStats" ? "#0a84ff" : "transparent",
              color: app.name === "MacStats" ? "#fff" : "#1a1c1f",
              borderRadius: 6, marginBottom: 2,
            }}>
              {app.isIcon
                ? <MacStatsIcon size={32} />
                : <div style={{ width: 32, height: 32, background: app.color, borderRadius: 7 }} />
              }
              <div style={{ flex: 1 }}>{app.name}</div>
              <div style={{ fontSize: 13, opacity: 0.6, fontFamily: "ui-monospace,'SF Mono',monospace" }}>
                {["4.2 MB", "6.8 MB", "3.1 MB", "5.4 MB", "12.3 MB"][i]}
              </div>
            </div>
          ))}
        </div>
      </DCArtboard>

      <DCArtboard id="menubar" label="Menu bar" width={900} height={120}>
        <div style={{
          width: "100%", height: "100%",
          background: "linear-gradient(135deg, #4a6fb8, #8b5ec7)",
          position: "relative",
        }}>
          <div style={{
            position: "absolute", top: 0, left: 0, right: 0, height: 48,
            background: "rgba(255,255,255,0.25)",
            backdropFilter: "blur(24px) saturate(180%)",
            WebkitBackdropFilter: "blur(24px) saturate(180%)",
            borderBottom: "1px solid rgba(255,255,255,0.2)",
            display: "flex", alignItems: "center", padding: "0 16px", gap: 16,
            fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif",
            color: "#fff", fontSize: 14, fontWeight: 500,
          }}>
            <MacStatsIcon size={22} />
            <span style={{ fontWeight: 600 }}>MacStats</span>
            <span style={{ opacity: 0.85, fontWeight: 400 }}>File</span>
            <span style={{ opacity: 0.85, fontWeight: 400 }}>View</span>
            <span style={{ opacity: 0.85, fontWeight: 400 }}>Window</span>
            <span style={{ opacity: 0.85, fontWeight: 400 }}>Help</span>
            <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 14, fontFamily: "ui-monospace,'SF Mono',monospace", fontSize: 12 }}>
              <span>CPU 42%</span>
              <span>RAM 68%</span>
              <span>14:32</span>
            </div>
          </div>
        </div>
      </DCArtboard>
    </DCSection>
  </DesignCanvas>
);

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
