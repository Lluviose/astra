import SwiftUI

/// 上床 / 没上床双柱月趋势。时间线用 6 个月，统计页用 12 个月。
struct OutcomeMonthChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let points: [EncounterInsights.MonthPoint]
    var barHeight: CGFloat = 70

    private var peak: Int {
        max(1, points.flatMap { [$0.hookups, $0.misses] }.max() ?? 1)
    }

    var body: some View {
        let hookupTotal = points.reduce(0) { $0 + $1.hookups }
        let missedTotal = points.reduce(0) { $0 + $1.misses }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("上床 \(hookupTotal)", systemImage: "flame.fill")
                    .foregroundStyle(EncounterKind.intimacy.tint)
                Spacer()
                Label("没上床 \(missedTotal)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(EncounterKind.missed.tint)
            }
            .font(.caption.weight(.semibold))

            HStack(alignment: .bottom, spacing: points.count > 6 ? 4 : 8) {
                ForEach(points) { item in
                    VStack(spacing: 4) {
                        Text("\(item.hookups)/\(item.misses)")
                            .font(.system(size: points.count > 6 ? 8 : 10, weight: .semibold))
                            .foregroundStyle(item.total > 0 ? Color.secondary : Color.secondary.opacity(0.45))
                            .contentTransition(reduceMotion ? .opacity : .numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        HStack(alignment: .bottom, spacing: 3) {
                            bar(item.hookups, tint: EncounterKind.intimacy.tint)
                            bar(item.misses, tint: EncounterKind.missed.tint)
                        }
                        .frame(height: barHeight + 4, alignment: .bottom)

                        Text(item.label)
                            .font(.system(size: points.count > 6 ? 9 : 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight + 42, alignment: .bottom)
            .animation(AstraMotion.response(reduceMotion: reduceMotion), value: points.map(\.total))
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("近 \(points.count) 个月：上床 \(hookupTotal) 次，没上床 \(missedTotal) 次")
    }

    private func bar(_ value: Int, tint: Color) -> some View {
        Capsule(style: .continuous)
            .fill(tint.gradient)
            .frame(
                width: points.count > 6 ? 6 : 8,
                height: value > 0 ? max(10, CGFloat(value) / CGFloat(peak) * barHeight) : 4
            )
            .opacity(value > 0 ? 1 : 0.16)
    }
}

/// 统计页里一行小数字：值 + 说明。
struct InsightFigure: View {
    let value: String
    let caption: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

