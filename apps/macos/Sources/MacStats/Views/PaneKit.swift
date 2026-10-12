import SwiftUI

/// Shared motion tokens. One spring for every UI state change: critically
/// damped (no overshoot), ~0.3 s. With Reduce Motion on, a short ease-out
/// cross-fade instead (gentler, not zero).
enum Motion {
    static func spring(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 1)
    }

    /// Content entering/leaving: fade plus a small drop, never from nothing.
    static func reveal(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -4))
    }
}

struct PaneHeader: View {
    let title: String
    let subtitle: String?
    let trailing: AnyView?

    init(title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.bottom, 12)
    }
}

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            content
        }
        .padding(16)
        .glassSurface(cornerRadius: 12)
    }
}

extension View {
    /// Liquid Glass on macOS 26+, flat control background with hairline below.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(shape.fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}

struct SparkShape: Shape {
    let values: [Double]
    let lo: Double
    let hi: Double
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count > 1, hi > lo else { return p }
        let stepX = rect.width / CGFloat(values.count - 1)
        let span = hi - lo
        func y(_ v: Double) -> CGFloat { rect.height * (1 - CGFloat((min(max(v, lo), hi) - lo) / span)) }
        p.move(to: CGPoint(x: 0, y: y(values[0])))
        for i in 1..<values.count { p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: y(values[i]))) }
        if closed {
            let base = y(max(lo, 0))
            p.addLine(to: CGPoint(x: rect.width, y: base))
            p.addLine(to: CGPoint(x: 0, y: base))
            p.closeSubpath()
        }
        return p
    }
}

struct AreaSpark: View, Equatable {
    let values: [Double]
    let max: Double
    let color: Color
    let height: CGFloat

    init(values: [Double], max: Double, color: Color = .accentColor, height: CGFloat = 80) {
        self.values = values
        self.max = max
        self.color = color
        self.height = height
    }

    var body: some View {
        ZStack {
            SparkShape(values: values, lo: 0, hi: max, closed: true)
                .fill(LinearGradient(colors: [color.opacity(0.45), color.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            SparkShape(values: values, lo: 0, hi: max, closed: false)
                .stroke(color, lineWidth: 1.4)
        }
        .frame(height: height)
    }
}

struct DualAreaSpark: View, Equatable {
    let inValues: [Double]
    let outValues: [Double]
    let max: Double
    let inColor: Color
    let outColor: Color
    let height: CGFloat

    init(
        inValues: [Double],
        outValues: [Double],
        max: Double,
        inColor: Color = .blue,
        outColor: Color = .orange,
        height: CGFloat = 80
    ) {
        self.inValues = inValues
        self.outValues = outValues
        self.max = max
        self.inColor = inColor
        self.outColor = outColor
        self.height = height
    }

    var body: some View {
        ZStack {
            SparkShape(values: inValues, lo: 0, hi: max, closed: false).stroke(inColor, lineWidth: 1.4)
            SparkShape(values: outValues, lo: 0, hi: max, closed: false).stroke(outColor, lineWidth: 1.4)
        }
        .frame(height: height)
    }
}

struct HistoryRangePicker: View {
    @Binding var selection: HistoryRange

    var body: some View {
        SlidingSegmented(options: HistoryRange.allCases, selection: $selection, label: \.label)
            .frame(width: 160)
    }
}

/// Segmented control whose blue selection pill slides to the tapped segment.
/// The native `.segmented` Picker jumps; this keeps its macOS 26 look (capsule
/// track, accent pill, white label) and adds the motion.
struct SlidingSegmented<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let selected = option == selection
                Button {
                    withAnimation(Motion.spring(reduceMotion: reduceMotion)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: 12))
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.08)))
    }
}

struct CenteredSpark: View, Equatable {
    let values: [Double]
    let color: Color
    let height: CGFloat

    var body: some View {
        let absMax = max((values.map { abs($0) }.max() ?? 1), 0.5)
        ZStack {
            SparkShape(values: values, lo: -absMax, hi: absMax, closed: true).fill(color.opacity(0.18))
            SparkShape(values: values, lo: -absMax, hi: absMax, closed: false).stroke(color, lineWidth: 1.6)
        }
        .frame(height: height)
    }
}

enum ScaleHelper {
    static func niceMax(_ values: [Double], minimum: Double = 1) -> Double {
        let peak = values.max() ?? 0
        return Swift.max(peak * 1.15, minimum)
    }
}
