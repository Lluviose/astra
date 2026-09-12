import SwiftUI

struct AchievementsScreen: View {
    @Environment(AppState.self) private var app

    @State private var category: AchievementCategory?
    @State private var selected: Achievement?
    @State private var hideUnlocked = false

    private var items: [Achievement] { app.achievements }
    private var unlocked: [Achievement] { items.filter(\.isUnlocked) }
    private var nextUp: [Achievement] { AchievementCatalog.nextUp(in: items) }
    private var visible: [Achievement] {
        let scoped = category.map { chapter in items.filter { $0.category == chapter } } ?? items
        return hideUnlocked ? scoped.filter { !$0.isUnlocked } : scoped
    }

    private var rank: RoyalRank { RoyalRank.resolve(from: items) }

    private func tierCount(_ tier: AchievementTier) -> Int {
        unlocked.filter { $0.tier == tier }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cover
                if !nextUp.isEmpty {
                    nextUpShelf
                }
                chapterPicker
                if chapters.isEmpty {
                    EmptyStateView(
                        symbol: "checkmark.seal.fill",
                        title: hideUnlocked ? "这一章全点亮了" : "这一章还没有徽章",
                        message: hideUnlocked ? "换一章看看，或关掉「只看未点亮」。" : "去记一笔，徽章会自己亮。"
                    )
                }
                ForEach(chapters, id: \.category) { chapter in
                    chapterBlock(chapter.category, items: chapter.items)
                }
            }
            .padding(AstraLayout.pageInset)
            .frame(maxWidth: AstraLayout.contentWidth)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("成就册")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { app.markAllUnlockedSeen() }
        .sheet(item: $selected) { achievement in
            AchievementDetailSheet(achievement: achievement, siblings: items.filter { $0.category == achievement.category })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var chapters: [(category: AchievementCategory, items: [Achievement])] {
        let grouped = Dictionary(grouping: visible, by: \.category)
        return AchievementCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    private var cover: some View {
        HeroPanel(cover: .gilded, cornerRadius: 28, watermark: "medal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HeroBadge(title: "只给你自己看")
                    Spacer()
                    HStack(spacing: 6) {
                        tierPill(.gold)
                        tierPill(.silver)
                        tierPill(.bronze)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Lv.\(rank.level) · \(rank.title)")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    Text(rank.nextRankText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                    Text("猎获、上床、复盘、足迹、私藏、玩法，一页一页点亮，每 10 枚升一级，最后把整本册子封神。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    MeterBar(value: rank.progressInBand, tint: Palette.gold, height: 5, onDark: true)
                    HStack {
                        Text("Lv.\(rank.level)")
                        Spacer()
                        if let next = rank.nextThreshold {
                            Text("\(unlocked.count) / \(next) 枚")
                                .monospacedDigit()
                        } else {
                            Text("已封神")
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 10) {
                    HeroMetric(value: "\(unlocked.count)", label: "已点亮")
                    HeroMetric(value: "\(items.count - unlocked.count)", label: "还没亮")
                    HeroMetric(
                        value: (Double(unlocked.count) / Double(max(items.count, 1)))
                            .formatted(.percent.precision(.fractionLength(0))),
                        label: "完成度"
                    )
                }
            }
        }
    }

    private func tierPill(_ tier: AchievementTier) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(tier.tint)
                .frame(width: 7, height: 7)
            Text("\(tierCount(tier))")
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.14), in: Capsule())
        .accessibilityLabel("\(tier.label)徽章 \(tierCount(tier)) 枚")
    }

    private var nextUpShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("快要点亮", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Palette.coral)
                Spacer()
                Text("最接近点亮的目标")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(nextUp) { achievement in
                        Button {
                            selected = achievement
                        } label: {
                            HStack(spacing: 12) {
                                AchievementProgressRing(achievement: achievement, size: 50)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(achievement.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.primary)
                                    Text("还差 \(achievement.remaining) · \(achievement.detail)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(achievement.progressText)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(achievement.tint)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .frame(width: 276, alignment: .leading)
                            .contentSurface(cornerRadius: 20)
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.98))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var chapterPicker: some View {
        let options = [PillOption<AchievementCategory?>(value: nil, title: "全册", systemImage: "book.closed.fill")]
            + AchievementCategory.allCases.map { item in
                let chapterItems = items.filter { $0.category == item }
                return PillOption<AchievementCategory?>(
                    value: item,
                    title: item.label,
                    systemImage: item.symbolName,
                    detail: "\(chapterItems.filter(\.isUnlocked).count)/\(chapterItems.count)"
                )
            }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PillPicker(options: options, selection: $category, tint: Palette.coral, scrollable: false)
                Divider().frame(height: 18)
                unlockedToggle
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var unlockedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { hideUnlocked.toggle() }
        } label: {
            Label("只看未点亮", systemImage: hideUnlocked ? "eye.slash.fill" : "eye")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(hideUnlocked ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(
                    hideUnlocked ? AnyShapeStyle(Palette.accent.gradient) : AnyShapeStyle(Palette.surface),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(hideUnlocked ? 0 : 0.08), lineWidth: 0.5)
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(HapticButtonStyle(cue: hideUnlocked ? .toggleOff : .toggleOn, scale: 0.96))
        .accessibilityAddTraits(hideUnlocked ? [.isSelected] : [])
    }

    private func chapterBlock(_ category: AchievementCategory, items: [Achievement]) -> some View {
        let chapterItems = self.items.filter { $0.category == category }
        let lit = chapterItems.filter(\.isUnlocked).count
        let complete = lit == chapterItems.count && !chapterItems.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(category.label, systemImage: category.symbolName)
                    .font(.headline)
                if complete {
                    Image(systemName: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.gold)
                        .accessibilityLabel("本章全部点亮")
                }
                Spacer()
                Text("\(lit)/\(chapterItems.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(complete ? Palette.goldDeep : .secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { achievement in
                    Button {
                        Haptics.shared.play(.selection)
                        selected = achievement
                    } label: {
                        AchievementCard(achievement: achievement)
                    }
                    .buttonStyle(.plain)
                    .scrollReveal()
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Medallion(
                    systemImage: achievement.symbolName,
                    tint: achievement.tint,
                    ring: achievement.tier.tint,
                    size: 44,
                    isLit: achievement.isUnlocked
                )
                Spacer()
                Text(achievement.tier.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(achievement.tier.tint)
            }

            Text(achievement.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
            Text(achievement.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            MeterBar(value: achievement.progress, tint: achievement.tint, height: 5)
            Text(achievement.progressText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(achievement.isUnlocked ? achievement.tint : .secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .contentSurface(cornerRadius: 20)
        .opacity(achievement.isUnlocked ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title)，\(achievement.category.label) \(achievement.tier.label)，\(achievement.detail)，\(achievement.progressText)")
    }
}

struct AchievementProgressRing: View {
    let achievement: Achievement
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .stroke(achievement.tint.opacity(0.14), lineWidth: max(4, size * 0.09))
            Circle()
                .trim(from: 0, to: max(0.035, CGFloat(achievement.progress)))
                .stroke(
                    achievement.tint.gradient,
                    style: StrokeStyle(lineWidth: max(4, size * 0.09), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: achievement.symbolName)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundStyle(achievement.tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct AchievementPreviewRow: View {
    let achievements: [Achievement]

    private var unlocked: [Achievement] { achievements.filter(\.isUnlocked) }
    private var next: Achievement? { AchievementCatalog.nextUp(in: achievements, limit: 1).first }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let next, !unlocked.isEmpty {
                    AchievementProgressRing(achievement: next)
                } else {
                    ZStack {
                        Circle()
                            .fill(Palette.coral.opacity(0.16))
                            .frame(width: 46, height: 46)
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Palette.coral)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("成就册")
                    .font(.headline)
                if unlocked.isEmpty {
                    Text("记下第一个她，成就册就翻开了")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let next {
                    Text("已点亮 \(unlocked.count)/\(achievements.count) · 还差 \(next.remaining)：\(next.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("全册点亮了")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .contentSurface(cornerRadius: 22)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AchievementDetailSheet: View {
    let achievement: Achievement
    /// 同一章的其余徽章，用来显示「本章 3/9」和下一枚。
    var siblings: [Achievement] = []

    @State private var bounce = 0

    private var chapterProgressText: String? {
        guard !siblings.isEmpty else { return nil }
        return "本章已点亮 \(siblings.filter(\.isUnlocked).count) / \(siblings.count)"
    }

    private var nextInChapter: Achievement? {
        AchievementCatalog.nextUp(in: siblings.filter { $0.id != achievement.id }, limit: 1).first
    }

    var body: some View {
        VStack(spacing: 16) {
            Medallion(
                systemImage: achievement.symbolName,
                tint: achievement.tint,
                ring: achievement.tier.tint,
                size: 84,
                isLit: achievement.isUnlocked,
                bounceTrigger: bounce
            )
            .padding(.top, 12)
            .task {
                try? await Task.sleep(for: .milliseconds(260))
                bounce += 1
            }

            HStack(spacing: 8) {
                TagLabel(title: achievement.category.label, systemImage: achievement.category.symbolName, tint: achievement.tint, filled: true)
                TagLabel(title: "\(achievement.tier.label)徽章", tint: achievement.tier.tint, filled: achievement.isUnlocked)
            }

            Text(achievement.title)
                .font(.title3.weight(.bold))
            Text(achievement.story)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                MeterBar(value: achievement.progress, tint: achievement.tint, height: 5)
                Text(achievement.isUnlocked ? "已点亮 · \(achievement.detail)" : "\(achievement.progressText) · \(achievement.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let chapterProgressText {
                    Text(chapterProgressText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)

            if achievement.isUnlocked, let next = nextInChapter {
                HStack(spacing: 10) {
                    AchievementProgressRing(achievement: next, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本章下一枚 · \(next.title)")
                            .font(.caption.weight(.semibold))
                        Text("还差 \(next.remaining) · \(next.detail)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .contentSurface(cornerRadius: 16)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .presentationBackground(.ultraThinMaterial)
    }
}

