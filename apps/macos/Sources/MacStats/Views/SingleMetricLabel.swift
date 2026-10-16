import SwiftUI

/// Text shown by one status item. `StatusBarController` writes it only when
/// the formatted string actually changes, so a tick that leaves "12%" as
/// "12%" doesn't invalidate the item's SwiftUI view.
@MainActor
final class MetricLabelModel: ObservableObject {
    @Published var text = ""
}

struct SingleMetricLabel: View {
    @ObservedObject var model: MetricLabelModel
    let metric: BarMetric

    var body: some View {
        if metric == .appIcon {
            AppIconLabel()
        } else {
            SingleMetricLabelContent(text: model.text, icon: metric.icon, width: width)
                .equatable()
        }
    }

    static func text(for metric: BarMetric, in snapshot: SystemSnapshot) -> String {
        switch metric {
        case .cpu:
            let v = Int(snapshot.cpu.usage.rounded())
            return String(format: "%d%%", min(max(v, 0), 100))
        case .temperature:
            let t = snapshot.temperature.cpuCelsius > 0
                ? snapshot.temperature.cpuCelsius
                : snapshot.temperature.maxCelsius
            if t > 0 { return String(format: "%d°", Int(t.rounded())) }
            return "--°"
        case .ram:
            let gb = Double(snapshot.memory.usedBytes) / 1_073_741_824.0
            return String(format: "%dG", Int(gb.rounded()))
        case .disk:
            return compactShort(snapshot.disk.readPerSec + snapshot.disk.writePerSec)
        case .network:
            return compactShort(snapshot.network.bytesInPerSec + snapshot.network.bytesOutPerSec)
        case .appIcon:
            return ""
        }
    }

    private static func compactShort(_ bps: Double) -> String {
        if bps < 1024 { return "0K" }
        if bps < 1024 * 1024 {
            return String(format: "%.0fK", bps / 1024)
        }
        if bps < 1024 * 1024 * 1024 {
            return String(format: "%.0fM", bps / 1024 / 1024)
        }
        return String(format: "%.0fG", bps / 1024 / 1024 / 1024)
    }

    private var width: CGFloat {
        switch metric {
        case .cpu: return 30
        case .temperature: return 26
        case .ram: return 32
        case .disk: return 36
        case .network: return 36
        case .appIcon: return 18
        }
    }
}

/// The app icon reduced to one colour for the menu bar (issue #13): its tile, filled in the
/// default foreground like the text items so it follows the menu bar's light / dark appearance,
/// with the icon's three rings and centre dot cut out of it. Measured from the icon on a 16-unit
/// grid: the tile is a superellipse (exponent 2.32, nearly round), the rings start at 12 o'clock
/// and run clockwise for 74 / 58 / 42% of a turn. Ring gaps are opened up a little from the
/// icon's so they survive at 16pt. Shared with the landing page's `AppGlyph`
/// (apps/web/src/components/Icon.tsx).
private struct AppIconLabel: View {
    /// (radius, fraction of a full turn), outermost first
    private static let rings: [(CGFloat, Double)] = [(5, 0.742), (3.6, 0.584), (2.2, 0.417)]

    var body: some View {
        Canvas { ctx, size in
            let u = size.width / 16
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.fill(Self.tile(centre: centre, halfWidth: 8 * u), with: .foreground)
            ctx.blendMode = .clear
            for (radius, turn) in Self.rings {
                var arc = Path()
                arc.addArc(center: centre, radius: radius * u, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * turn), clockwise: false)
                ctx.stroke(arc, with: .foreground, style: StrokeStyle(lineWidth: 0.85 * u, lineCap: .round))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: centre.x - 0.7 * u, y: centre.y - 0.7 * u, width: 1.4 * u, height: 1.4 * u)), with: .foreground)
        }
        .frame(width: 16, height: 16)
        .padding(.horizontal, 2)
    }

    /// |x|^n + |y|^n = 1 with n = 2.32, the icon's own outline
    private static func tile(centre: CGPoint, halfWidth a: CGFloat) -> Path {
        Path { p in
            for i in 0..<96 {
                let t = Double(i) / 96 * 2 * .pi
                let x = copysign(pow(abs(cos(t)), 2 / 2.32), cos(t))
                let y = copysign(pow(abs(sin(t)), 2 / 2.32), sin(t))
                let point = CGPoint(x: centre.x + a * x, y: centre.y + a * y)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
        }
    }
}

private struct SingleMetricLabelContent: View, Equatable {
    let text: String
    let icon: String
    let width: CGFloat

    private static let valueFont = Font.system(size: 9, weight: .bold).monospacedDigit()
    private static let iconFont = Font.system(size: 9, weight: .semibold)

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(Self.iconFont)
            Text(text)
                .font(Self.valueFont)
                .lineLimit(1)
                .frame(width: width, alignment: .center)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
