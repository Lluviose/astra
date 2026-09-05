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
        case .hookups: "上床"
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
        case .overall: Palette.accent
        case .desire: Palette.coral
        case .chemistry: Palette.coral
        case .afterglow: Palette.accent
        case .hookups: Palette.warning
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

    @Environment(\.dynamicTypeSize) private var typeSize
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
            .padding(AstraLayout.gutter)
            .astraContentMargins()
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
        HeroPanel(cornerRadius: 28, watermark: "crown.fill") {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.13))
                        .frame(width: 72, height: 72)
                    Image(systemName: "crown.fill")
                        .font(.system(.largeTitle, design: .serif).weight(.regular))
                        .foregroundStyle(Palette.gold)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("你的私密榜单")
                        .font(.title2.weight(.bold))
                    Text("只按你留下的分数和次数在本机排，\(ranked.count) 人上榜。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyMessage: String {
        metric == .hookups
            ? "先记下一次上床，这里会按次数排出你的私密榜单。"
            : "先在档案里留下对应评分，这里会自动排出你的私密榜单。"
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CompanionRankingMetric.allCases) { item in
                    GlassChip(title: item.label, systemImage: item.symbolName, isOn: metric == item, compact: true) {
                        metric = item
                    }
                }
            }
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

            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
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
        .astraSurface(cornerRadius: 20)
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
            .astraSurface(cornerRadius: 22)
        }
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: Palette.goldDeep
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


