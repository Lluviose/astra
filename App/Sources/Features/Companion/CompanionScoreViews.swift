import SwiftUI

struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 56
    var showsLabel: Bool = true

    private var progress: CGFloat {
        CGFloat(min(max(score, 0), 100)) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: max(5, size * 0.09))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [Color.white, Color(red: 1, green: 0.58, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: max(5, size * 0.09), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if showsLabel {
                VStack(spacing: -2) {
                    Text("\(score)")
                        .font(.system(size: size * 0.30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("分")
                        .font(.system(size: size * 0.13, weight: .semibold))
                        .opacity(0.64)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("综合评分 \(score) 分")
    }
}

struct CompanionScoreBadge: View {
    let score: Int
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: score > 0 ? "flame.fill" : "slider.horizontal.3")
            if score > 0 {
                Text("\(score)")
                    .monospacedDigit()
                if !compact { Text("分") }
            } else {
                Text("待评")
            }
        }
        .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 4 : 5)
        .background((score > 0 ? Palette.coral : Color.secondary).gradient, in: Capsule())
        .accessibilityLabel(score > 0 ? "综合评分 \(score) 分" : "尚未评分")
    }
}

struct ScorecardEditorLink: View {
    let scorecard: CompanionScorecard

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Palette.coral.opacity(0.14))
                    .frame(width: 58, height: 58)
                Text(scorecard.overallScore > 0 ? "\(scorecard.overallScore)" : "—")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Palette.coral)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(scorecard.overallScore > 0 ? "综合 \(scorecard.overallScore) 分" : "还没评分")
                    .font(.headline)
                Text("颜值、身材、默契、主动、欲望、回味")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct CompanionScoreSummaryView: View {
    let scorecard: CompanionScorecard

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Palette.coral.opacity(0.14))
                        .frame(width: 64, height: 64)
                    VStack(spacing: -2) {
                        Text(scorecard.overallScore > 0 ? "\(scorecard.overallScore)" : "—")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Palette.coral)
                            .monospacedDigit()
                        Text("综合")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(scoreHeadline)
                        .font(.headline)
                    Text("已完成 \(scorecard.completedCount)/\(CompanionScoreDimension.allCases.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CompanionScoreDimension.allCases) { dimension in
                    let value = scorecard.value(for: dimension)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Label(dimension.shortLabel, systemImage: dimension.symbolName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(dimension.tint)
                            Spacer()
                            Text("\(value)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                        }
                        ProgressView(value: Double(value), total: 10)
                            .tint(dimension.tint)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var scoreHeadline: String {
        switch scorecard.overallScore {
        case 90...: "念念不忘"
        case 80...: "很容易上头"
        case 70...: "明显有吸引力"
        case 60...: "有感觉"
        case 1...: "还可以再观察"
        default: "还没打分"
        }
    }
}

struct CompanionScoreEditor: View {
    @Binding var scorecard: CompanionScorecard

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                presets

                ForEach(CompanionScoreDimension.allCases) { dimension in
                    ScoreDimensionControl(
                        dimension: dimension,
                        value: Binding(
                            get: { scorecard.value(for: dimension) },
                            set: { scorecard.set($0, for: dimension) }
                        )
                    )
                }

                Text("0 表示暂不评分。分数只在私人档案里显示，并可随设备 iCloud Backup 恢复。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
            .padding(AstraLayout.pageInset)
            .frame(maxWidth: AstraLayout.contentWidth)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("私密评分")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        HeroPanel(cornerRadius: 26, glow: Palette.coral, padding: 18) {
        HStack(spacing: 18) {
            ScoreRing(score: scorecard.overallScore, size: 82)

            VStack(alignment: .leading, spacing: 6) {
                Text("这一眼，有多上头？")
                    .font(.title3.weight(.bold))
                Text("拨动六条刻度，综合分会即时变化。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快速落笔")
                .font(.headline)

            HStack(spacing: 8) {
                presetButton("有感觉", symbol: "heart.fill", value: .feeling)
                presetButton("很上头", symbol: "flame.fill", value: .heated)
                presetButton("忘不掉", symbol: "sparkles", value: .obsessed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .contentSurface(cornerRadius: 22)
    }

    private func presetButton(_ title: String, symbol: String, value: ScorePreset) -> some View {
        Button {
            scorecard = value.scorecard
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(value.tint.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(HapticButtonStyle(cue: .mediumTap, scale: 0.95))
    }
}

private struct ScoreDimensionControl: View {
    let dimension: CompanionScoreDimension
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(dimension.label, systemImage: dimension.symbolName)
                    .font(.headline)
                    .foregroundStyle(dimension.tint)
                Spacer()
                Text(value == 0 ? "未评分" : "\(value) / 10")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(value == 0 ? Color.secondary : dimension.tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 0...10,
                step: 1
            )
            .tint(dimension.tint)
            .haptic(.selection, trigger: value)

            HStack {
                Text("留白")
                Spacer()
                Text(feelingText)
                Spacer()
                Text("顶格")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .contentSurface(cornerRadius: 20)
    }

    private var feelingText: String {
        switch value {
        case 9...10: "非常上头"
        case 7...8: "吸引力很强"
        case 4...6: "有感觉"
        case 1...3: "感觉一般"
        default: "按感觉拨动"
        }
    }
}

private enum ScorePreset {
    case feeling
    case heated
    case obsessed

    var tint: Color {
        switch self {
        case .feeling: Palette.accent
        case .heated: Palette.coral
        case .obsessed: Color(red: 0.80, green: 0.20, blue: 0.42)
        }
    }

    var scorecard: CompanionScorecard {
        switch self {
        case .feeling:
            CompanionScorecard(looks: 6, body: 6, chemistry: 6, initiative: 6, desire: 7, afterglow: 6)
        case .heated:
            CompanionScorecard(looks: 8, body: 8, chemistry: 9, initiative: 7, desire: 9, afterglow: 8)
        case .obsessed:
            CompanionScorecard(looks: 9, body: 9, chemistry: 10, initiative: 9, desire: 10, afterglow: 10)
        }
    }
}

