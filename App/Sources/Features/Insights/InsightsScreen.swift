import SwiftUI

/// 战绩统计：把全部记录拆成结果、套、玩法、时段、人和地点几块。
struct InsightsScreen: View {

    @Environment(AppState.self) private var app

    private var insights: EncounterInsights { app.insights }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                cover

                if insights.isEmpty {
                    EmptyStateView(
                        symbol: "chart.bar.xaxis",
                        title: "还没有可统计的记录",
                        message: "记下几次上床或没上床，这里会自动算出上床率、套的情况、最常做的和最常约的时段。"
                    )
                    .astraSurface(cornerRadius: 24)
                } else {
                    trendCard
                    if insights.hookupCount > 0 {
                        protectionCard
                        if !insights.topActivities.isEmpty { activityCard }
                        if !insights.topClimaxDetails.isEmpty { climaxCard }
                        rhythmCard
                        companionsCard
                        if !insights.topLocations.isEmpty { locationsCard }
                        spendCard
                    }
                    if insights.wantAgainRate != nil { meetAgainCard }
                }
            }
            .padding(AstraLayout.gutter)
            .astraContentMargins()
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("相处统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 封面

    private var cover: some View {
        HeroPanel(watermark: "chart.bar.xaxis") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HeroBadge(title: "只按你的记录算")
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(insights.isEmpty ? "还没开张" : headline)
                        .font(.system(.largeTitle, design: .serif).weight(.regular))
                    Text(subheadline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    HeroMetric(value: "\(insights.hookupCount)", label: "上床")
                    HeroMetric(value: "\(insights.missedCount)", label: "没上")
                    HeroMetric(value: percent(insights.hookupRate), label: "上床率")
                    HeroMetric(value: "\(insights.companionCount)", label: "个她")
                }
            }
        }
    }

    private var headline: String {
        guard let rate = insights.hookupRate else { return "还没开张" }
        switch rate {
        case 0.8...: return "几乎逢约必上"
        case 0.6..<0.8: return "手感很稳"
        case 0.4..<0.6: return "一半一半"
        case 0.2..<0.4: return "还在铺场子"
        default: return "先把没成的记清楚"
        }
    }

    private var subheadline: String {
        var parts: [String] = []
        if let busiest = insights.busiestMonth {
            parts.append("最猛的月份是 \(busiest.label)，上了 \(busiest.hookups) 次")
        }
        if let part = insights.favoriteDayPart {
            parts.append("最常在\(part.label)")
        }
        if parts.isEmpty { return "上床、没上床、套、玩法和时段，全在这一页。" }
        return parts.joined(separator: "；") + "。"
    }

    // MARK: 趋势

    private var trendCard: some View {
        SectionCard("近 12 个月", systemImage: "chart.bar.fill", tint: Palette.coral) {
            if let busiest = insights.busiestMonth {
                Text("峰值 \(busiest.label)")
            }
        } content: {
            OutcomeMonthChart(points: insights.months, barHeight: 64)
        }
    }

    // MARK: 套

    private var protectionCard: some View {
        let ordered: [ProtectionStatus] = [.protected, .partial, .noProtection, .notRecorded]
        let counts = ordered.map { (status: $0, count: insights.protectionCounts[$0] ?? 0) }
        let total = max(1, counts.reduce(0) { $0 + $1.count })
        return SectionCard("有没有戴套", systemImage: "checkmark.shield.fill", tint: Palette.safe) {
            if let rate = insights.protectedRate {
                Text("记了套的里 \(percent(rate)) 全程戴")
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        ForEach(counts, id: \.status) { item in
                            if item.count > 0 {
                                Rectangle()
                                    .fill(protectionTint(item.status))
                                    .frame(width: max(4, proxy.size.width * CGFloat(item.count) / CGFloat(total)))
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)

                FlowLayout(spacing: 10, lineSpacing: 6) {
                    ForEach(counts, id: \.status) { item in
                        HStack(spacing: 5) {
                            Circle().fill(protectionTint(item.status)).frame(width: 8, height: 8)
                            Text("\(item.status == .notRecorded ? "没记" : item.status.compactLabel) \(item.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if insights.barrierGapCount > 0 {
                    Text("有 \(insights.barrierGapCount) 次没戴全或没戴。要做检测的话，去对应记录里勾一下。")
                        .font(.caption)
                        .foregroundStyle(Palette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func protectionTint(_ status: ProtectionStatus) -> Color {
        switch status {
        case .notRecorded, .notApplicable: Color.secondary.opacity(0.35)
        default: status.tint
        }
    }

    // MARK: 玩法

    private var activityCard: some View {
        let peak = insights.topActivities.first?.count ?? 1
        return SectionCard("最常做的", systemImage: "flame.fill", tint: Palette.coral) {
            Text("\(insights.hookupCount) 次里")
        } content: {
            VStack(spacing: 10) {
                ForEach(insights.topActivities) { item in
                    InsightBarRow(
                        title: item.item.label,
                        count: item.count,
                        peak: peak,
                        tint: item.item.group == .heat || item.item.group == .place ? Palette.coral : Palette.accent
                    )
                }
            }
        }
    }

    private var climaxCard: some View {
        let peak = insights.topClimaxDetails.first?.count ?? 1
        return SectionCard("怎么收的", systemImage: "drop.fill", tint: Color(red: 0.94, green: 0.22, blue: 0.46)) {
            VStack(spacing: 10) {
                ForEach(insights.topClimaxDetails) { item in
                    InsightBarRow(title: item.item.label, count: item.count, peak: peak, tint: item.item.tint)
                }
            }
        }
    }

    // MARK: 时段与节奏

    private var rhythmCard: some View {
        let dayPeak = max(1, insights.dayParts.map(\.count).max() ?? 1)
        let weekPeak = max(1, insights.weekdays.map(\.count).max() ?? 1)
        return SectionCard("什么时候上", systemImage: "clock.fill", tint: Palette.accent) {
            if let part = insights.favoriteDayPart {
                Text("偏爱\(part.label)")
            }
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(insights.dayParts) { item in
                        VStack(spacing: 6) {
                            Text("\(item.count)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(item.count > 0 ? Palette.accent : .secondary)
                            Capsule()
                                .fill(Palette.accent.gradient)
                                .frame(height: item.count > 0 ? max(10, CGFloat(item.count) / CGFloat(dayPeak) * 56) : 4)
                                .opacity(item.count > 0 ? 1 : 0.18)
                                .frame(maxWidth: .infinity)
                            Image(systemName: item.item.symbolName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(item.item.label)
                                .font(.caption2.weight(.semibold))
                            Text(item.item.hoursLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Divider()

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(insights.weekdays) { item in
                        VStack(spacing: 5) {
                            Text("\(item.count)")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(item.count > 0 ? Palette.coral : .secondary)
                            Capsule()
                                .fill(Palette.coral.gradient)
                                .frame(width: 10, height: item.count > 0 ? max(8, CGFloat(item.count) / CGFloat(weekPeak) * 40) : 4)
                                .opacity(item.count > 0 ? 1 : 0.18)
                            Text(EncounterInsights.weekdayLabel(item.item))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 12) {
                    InsightFigure(value: days(insights.daysSinceLastHookup), caption: "距上次上床")
                    InsightFigure(value: insights.averageGapDays.map { "\(Int($0.rounded())) 天" } ?? "—", caption: "平均间隔")
                    InsightFigure(value: days(insights.longestGapDays), caption: "最长空窗")
                }
            }
        }
    }

    // MARK: 人与地点

    private var companionsCard: some View {
        let peak = insights.topCompanions.first?.count ?? 1
        return SectionCard("上得最多的", systemImage: "crown.fill", tint: Palette.goldDeep) {
            Text("回头客 \(insights.repeatCompanionCount)")
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(insights.topCompanions.enumerated()), id: \.element.id) { index, item in
                    if let companion = app.companion(id: item.item) {
                        NavigationLink(value: companion.id) {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(index == 0 ? Palette.goldDeep : .secondary)
                                    .frame(width: 20)
                                AvatarView(companion: companion, size: 38)
                                VStack(alignment: .leading, spacing: 4) {
                                    MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                                    GeometryReader { proxy in
                                        Capsule()
                                            .fill(Palette.coral.gradient)
                                            .frame(width: max(6, proxy.size.width * CGFloat(item.count) / CGFloat(max(peak, 1))))
                                    }
                                    .frame(height: 5)
                                }
                                Spacer()
                                Text("\(item.count) 次")
                                    .font(.subheadline.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.coral)
                                ChevronHint()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < insights.topCompanions.count - 1 {
                            Divider().padding(.leading, 70)
                        }
                    }
                }
            }
        }
    }

    private var locationsCard: some View {
        let peak = insights.topLocations.first?.count ?? 1
        return SectionCard("哪儿上得多", systemImage: "map.fill", tint: Palette.safe) {
            Text("\(insights.locationCount) 个地点")
        } content: {
            VStack(spacing: 10) {
                ForEach(insights.topLocations) { item in
                    InsightBarRow(
                        title: app.locationName(id: item.item),
                        count: item.count,
                        peak: peak,
                        tint: Palette.safe,
                        systemImage: "mappin"
                    )
                }
            }
        }
    }

    // MARK: 花费与感受

    private var spendCard: some View {
        SectionCard("花了多少，爽不爽", systemImage: "yensign.circle.fill", tint: Palette.warning) {
            HStack(spacing: 12) {
                InsightFigure(
                    value: insights.spendRecordedCount > 0 ? Format.money(insights.totalSpend) : "—",
                    caption: "记了花费的 \(insights.spendRecordedCount) 次合计",
                    tint: Palette.warning
                )
                InsightFigure(
                    value: insights.averageSpend.map { Format.money($0) } ?? "—",
                    caption: "平均每次"
                )
            }
            Divider()
            HStack(spacing: 12) {
                InsightFigure(
                    value: insights.averagePhysical.map { String(format: "%.1f / 5", $0) } ?? "—",
                    caption: "身体感受"
                )
                InsightFigure(
                    value: insights.averageEmotional.map { String(format: "%.1f / 5", $0) } ?? "—",
                    caption: "情绪感受"
                )
            }
        }
    }

    private var meetAgainCard: some View {
        let ordered: [MeetAgainIntent] = [.yes, .maybe, .no]
        let peak = max(1, ordered.map { insights.meetAgainCounts[$0] ?? 0 }.max() ?? 1)
        return SectionCard("还想不想再约", systemImage: "arrow.forward.circle.fill", tint: Palette.accent) {
            if let rate = insights.wantAgainRate {
                Text("\(percent(rate)) 还想约")
            }
        } content: {
            VStack(spacing: 10) {
                ForEach(ordered) { intent in
                    InsightBarRow(
                        title: intent.label,
                        count: insights.meetAgainCounts[intent] ?? 0,
                        peak: peak,
                        tint: intent == .yes ? Palette.coral : (intent == .maybe ? Palette.warning : Color.secondary)
                    )
                }
            }
        }
    }

    // MARK: 格式

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func days(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) 天"
    }
}
