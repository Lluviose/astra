import Charts
import SwiftUI

/// 上床 / 没上床双柱月趋势。时间线用 6 个月，统计页用 12 个月。
struct OutcomeMonthChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let points: [EncounterInsights.MonthPoint]
    var barHeight: CGFloat = 70

    private static let hookupSeries = "上床"
    private static let missedSeries = "没上床"

    private var peak: Int {
        max(1, points.flatMap { [$0.hookups, $0.misses] }.max() ?? 1)
    }

    private var hookupTotal: Int { points.reduce(0) { $0 + $1.hookups } }
    private var missedTotal: Int { points.reduce(0) { $0 + $1.misses } }

    private var monthlyAverage: Double? {
        guard hookupTotal > 0, !points.isEmpty else { return nil }
        return Double(hookupTotal) / Double(points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                legend(Self.hookupSeries, count: hookupTotal, tint: EncounterKind.intimacy.tint)
                Spacer()
                legend(Self.missedSeries, count: missedTotal, tint: EncounterKind.missed.tint)
            }

            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("月份", point.monthStart, unit: .month),
                        y: .value("次数", Double(point.hookups))
                    )
                    .foregroundStyle(by: .value("结果", Self.hookupSeries))
                    .position(by: .value("结果", Self.hookupSeries))
                    .cornerRadius(3)

                    BarMark(
                        x: .value("月份", point.monthStart, unit: .month),
                        y: .value("次数", Double(point.misses))
                    )
                    .foregroundStyle(by: .value("结果", Self.missedSeries))
                    .position(by: .value("结果", Self.missedSeries))
                    .cornerRadius(3)
                }

                if let monthlyAverage {
                    RuleMark(y: .value("月均", monthlyAverage))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("月均 \(monthlyAverage.formatted(.number.precision(.fractionLength(1))))")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartForegroundStyleScale([
                Self.hookupSeries: EncounterKind.intimacy.tint,
                Self.missedSeries: EncounterKind.missed.tint,
            ])
            .chartLegend(.hidden)
            .chartYScale(domain: 0...Double(peak))
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .font(.system(size: points.count > 6 ? 9 : 11))
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: barHeight + 44)
            .animation(AstraMotion.response(reduceMotion: reduceMotion), value: points.map(\.total))
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("近 \(points.count) 个月：上床 \(hookupTotal) 次，没上床 \(missedTotal) 次")
    }

    private func legend(_ title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text("\(title) \(count)")
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText())
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
    }
}

/// 统计页里一行小数字：值 + 说明。
struct InsightFigure: View {
    let value: String
    let caption: String
    var tint: Color = .primary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
