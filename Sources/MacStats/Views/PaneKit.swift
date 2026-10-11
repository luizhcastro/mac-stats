import SwiftUI

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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
        Picker("Range", selection: $selection) {
            ForEach(HistoryRange.allCases) { r in
                Text(r.label).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 160)
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
