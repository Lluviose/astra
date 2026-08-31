import SwiftUI

struct AchievementsScreen: View {
    @Environment(AppState.self) private var app

    @State private var category: AchievementCategory?
    @State private var selected: Achievement?

    private var items: [Achievement] { app.achievements }
    private var unlocked: [Achievement] { items.filter(\.isUnlocked) }
    private var visible: [Achievement] {
        guard let category else { return items }
        return items.filter { $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cover
                chapterPicker
                ForEach(chapters, id: \.category) { chapter in
                    chapterBlock(chapter.category, items: chapter.items)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("成就册")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { app.markAllUnlockedSeen() }
        .sheet(item: $selected) { achievement in
            AchievementDetailSheet(achievement: achievement)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("只给你自己看", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
                Spacer()
                Text("\(unlocked.filter { $0.tier == .gold }.count) 金")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
            }

            Text("成就册")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("猎获、约成、过夜、足迹、私藏，一页一页点亮。不算排行榜。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                coverMetric("\(unlocked.count)", "已点亮")
                coverMetric("\(items.count - unlocked.count)", "还没点")
                coverMetric("\(items.count)", "全册")
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(Palette.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Palette.accentDeep.opacity(0.28), radius: 18, y: 10)
    }

    private func coverMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chapterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chapterChip(nil, title: "全册", symbol: "book.closed.fill")
                ForEach(AchievementCategory.allCases) { item in
                    chapterChip(item, title: item.label, symbol: item.symbolName)
                }
            }
        }
    }

    private func chapterChip(_ value: AchievementCategory?, title: String, symbol: String) -> some View {
        let on = category == value
        return Button {
            Haptics.shared.play(.selection)
            category = value
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(on ? .white : .primary)
                .background {
                    if on { Capsule().fill(Palette.coral.gradient) }
                }
                .glassCapsule(interactive: true, shadowRadius: 6)
        }
        .buttonStyle(.plain)
    }

    private func chapterBlock(_ category: AchievementCategory, items: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(category.label, systemImage: category.symbolName)
                    .font(.headline)
                Spacer()
                Text("\(items.filter(\.isUnlocked).count)/\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
                ZStack {
                    Circle()
                        .fill(achievement.tint.opacity(achievement.isUnlocked ? 0.22 : 0.10))
                        .frame(width: 44, height: 44)
                    Circle()
                        .strokeBorder(achievement.tier.tint.opacity(achievement.isUnlocked ? 0.9 : 0.25), lineWidth: 1.6)
                        .frame(width: 44, height: 44)
                    Image(systemName: achievement.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(achievement.isUnlocked ? achievement.tint : Color.secondary)
                }
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

            ProgressView(value: achievement.progress)
                .tint(achievement.tint)
            Text(achievement.progressText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(achievement.isUnlocked ? achievement.tint : .secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .glassCard(cornerRadius: 20, shadowRadius: 8)
        .opacity(achievement.isUnlocked ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title)，\(achievement.category.label) \(achievement.tier.label)，\(achievement.detail)，\(achievement.progressText)")
    }
}

struct AchievementPreviewRow: View {
    let achievements: [Achievement]

    private var unlocked: [Achievement] { achievements.filter(\.isUnlocked) }
    private var next: Achievement? { achievements.first { !$0.isUnlocked } }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Palette.coral.opacity(0.16))
                    .frame(width: 46, height: 46)
                Image(systemName: "crown.fill")
                    .foregroundStyle(Palette.coral)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("成就册")
                    .font(.headline)
                if let next {
                    Text("已点亮 \(unlocked.count)/\(achievements.count) · 下一页：\(next.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if unlocked.isEmpty {
                    Text("记下第一个她，成就册就翻开了")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .glassCard(cornerRadius: 22, interactive: true, shadowRadius: 10)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AchievementDetailSheet: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(achievement.tint.opacity(achievement.isUnlocked ? 0.22 : 0.10))
                    .frame(width: 84, height: 84)
                Circle()
                    .strokeBorder(achievement.tier.tint, lineWidth: 2)
                    .frame(width: 84, height: 84)
                Image(systemName: achievement.symbolName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? achievement.tint : .secondary)
            }
            .padding(.top, 12)

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
                ProgressView(value: achievement.progress)
                    .tint(achievement.tint)
                Text(achievement.isUnlocked ? "已点亮 · \(achievement.detail)" : "\(achievement.progressText) · \(achievement.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .presentationBackground(.ultraThinMaterial)
    }
}
