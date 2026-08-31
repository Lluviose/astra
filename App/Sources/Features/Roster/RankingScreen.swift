import SwiftUI

enum CompanionRankingMetric: String, CaseIterable, Identifiable {
    case overall
    case desire
    case chemistry
    case afterglow
    case hookups

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overall: "综合"
        case .desire: "欲望"
        case .chemistry: "床上"
        case .afterglow: "回味"
        case .hookups: "约成"
        }
    }

    var symbolName: String {
        switch self {
        case .overall: "crown.fill"
        case .desire: "flame.fill"
        case .chemistry: "bolt.heart.fill"
        case .afterglow: "repeat.circle.fill"
        case .hookups: "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .overall: Color(red: 0.96, green: 0.66, blue: 0.22)
        case .desire: Palette.coral
        case .chemistry: Color(red: 0.80, green: 0.24, blue: 0.62)
        case .afterglow: Palette.accent
        case .hookups: Color(red: 0.95, green: 0.48, blue: 0.28)
        }
    }

    @MainActor
    func value(for companion: Companion, app: AppState) -> Int {
        switch self {
        case .overall: companion.overallScore
        case .desire: companion.scorecard.desire
        case .chemistry: companion.scorecard.chemistry
        case .afterglow: companion.scorecard.afterglow
        case .hookups: app.hookupCount(for: companion.id)
        }
    }

    @MainActor
    func valueText(for companion: Companion, app: AppState) -> String {
        let value = value(for: companion, app: app)
        return switch self {
        case .overall: "\(value) 分"
        case .desire, .chemistry, .afterglow: "\(value) / 10"
        case .hookups: "\(value) 次"
        }
    }
}

struct RankingScreen: View {
    @Environment(AppState.self) private var app

    @State private var metric: CompanionRankingMetric = .overall
    @State private var includeArchived = false

    private var ranked: [Companion] {
        let source = includeArchived ? app.companions : app.companions.filter { !$0.isArchived }
        return source.filter { metric.value(for: $0, app: app) > 0 }.sorted { lhs, rhs in
            let left = metric.value(for: lhs, app: app)
            let right = metric.value(for: rhs, app: app)
            if left != right { return left > right }
            if lhs.overallScore != rhs.overallScore { return lhs.overallScore > rhs.overallScore }
            return app.lastContact(for: lhs) > app.lastContact(for: rhs)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cover
                metricPicker

                if ranked.isEmpty {
                    EmptyStateView(
                        symbol: "crown",
                        title: "还没有人上榜",
                        message: emptyMessage
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    podium
                    rankingList
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("私密排行")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.toggleNamesRevealed()
                } label: {
                    Image(systemName: app.namesRevealed ? "eye.slash" : "eye")
                }
                .accessibilityLabel(app.namesRevealed ? "隐藏代号" : "显示代号")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("包含已归档", isOn: $includeArchived)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("排行选项")
            }
        }
    }

    private var cover: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 72, height: 72)
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.28))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("你的猎艳榜单")
                    .font(.title2.weight(.bold))
                Text("只按你留下的分数在本机计算，可随设备备份恢复。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(Palette.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Palette.accentDeep.opacity(0.26), radius: 18, y: 9)
    }

    private var emptyMessage: String {
        metric == .hookups
            ? "先记下一次约成，这里会按次数排出你的私密榜单。"
            : "先在档案里留下对应评分，这里会自动排出你的私密榜单。"
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CompanionRankingMetric.allCases) { item in
                    Button {
                        metric = item
                    } label: {
                        Label(item.label, systemImage: item.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(metric == item ? .white : Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                if metric == item {
                                    Capsule().fill(item.tint.gradient)
                                }
                            }
                            .glassCapsule(interactive: true, shadowRadius: 6)
                    }
                    .buttonStyle(HapticButtonStyle(cue: .selection, scale: 0.96))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var podium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("前三名", systemImage: metric.symbolName)
                    .font(.headline)
                    .foregroundStyle(metric.tint)
                Spacer()
                Text(metric.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(ranked.prefix(3).enumerated()), id: \.element.id) { index, companion in
                    NavigationLink(value: companion.id) {
                        podiumCard(companion, rank: index + 1)
                    }
                    .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.96))
                }
            }
        }
    }

    private func podiumCard(_ companion: Companion, rank: Int) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                AvatarView(companion: companion, size: rank == 1 ? 62 : 54)
                Text("\(rank)")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(medalColor(rank).gradient, in: Circle())
                    .offset(x: -5, y: -5)
            }

            MaskedName(
                name: companion.displayName,
                revealed: app.namesRevealed,
                font: .caption.weight(.bold)
            )
            .frame(maxWidth: .infinity)

            Text(metric.valueText(for: companion, app: app))
                .font(.caption2.weight(.bold))
                .foregroundStyle(metric.tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, rank == 1 ? 16 : 13)
        .padding(.horizontal, 6)
        .glassCard(cornerRadius: 20, interactive: true, shadowRadius: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("完整名次", systemImage: "list.number")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, companion in
                    NavigationLink(value: companion.id) {
                        RankingRow(
                            companion: companion,
                            rank: index + 1,
                            value: metric.valueText(for: companion, app: app),
                            tint: metric.tint
                        )
                    }
                    .buttonStyle(.plain)

                    if index < ranked.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .padding(.horizontal, 14)
            .glassCard(cornerRadius: 22, shadowRadius: 9)
        }
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: Color(red: 0.95, green: 0.70, blue: 0.18)
        case 2: Color(red: 0.62, green: 0.67, blue: 0.76)
        default: Color(red: 0.76, green: 0.45, blue: 0.24)
        }
    }
}

private struct RankingRow: View {
    let companion: Companion
    let rank: Int
    let value: String
    let tint: Color

    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(rank <= 3 ? tint : .secondary)
                .frame(width: 24)

            AvatarView(companion: companion, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                Text(companion.stage.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct RankingPreviewCard: View {
    @Environment(AppState.self) private var app

    private var top: [Companion] {
        Array(
            app.companions
                .filter { !$0.isArchived && $0.overallScore > 0 }
                .sorted {
                    if $0.overallScore != $1.overallScore { return $0.overallScore > $1.overallScore }
                    return app.lastContact(for: $0) > app.lastContact(for: $1)
                }
                .prefix(3)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("私密排行", systemImage: "crown.fill")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.92, green: 0.62, blue: 0.18))
                Spacer()
                Text("看完整榜单")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }

            if top.isEmpty {
                Text("给档案打分后，这里会出现前三名。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, companion in
                        VStack(spacing: 5) {
                            AvatarView(companion: companion, size: 42)
                            MaskedName(
                                name: companion.displayName,
                                revealed: app.namesRevealed,
                                font: .caption2.weight(.semibold)
                            )
                            Text("#\(index + 1) · \(companion.overallScore)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.coral)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
