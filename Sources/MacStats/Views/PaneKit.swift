import SwiftUI
import Charts

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

struct AreaSpark: View {
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
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
                AreaMark(
                    x: .value("t", idx),
                    yStart: .value("min", 0),
                    yEnd: .value("v", v)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.45), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(x: .value("t", idx), y: .value("v", v))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
        }
        .chartYScale(domain: 0...max)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}

struct DualAreaSpark: View {
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
        Chart {
            ForEach(Array(inValues.enumerated()), id: \.offset) { idx, v in
                LineMark(x: .value("t", idx), y: .value("in", v))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(inColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
            ForEach(Array(outValues.enumerated()), id: \.offset) { idx, v in
                LineMark(x: .value("t", idx), y: .value("out", v))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(outColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
        }
        .chartYScale(domain: 0...max)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}

enum ScaleHelper {
    static func niceMax(_ values: [Double], minimum: Double = 1) -> Double {
        let peak = values.max() ?? 0
        return Swift.max(peak * 1.15, minimum)
    }
}
