import SwiftUI

struct AchievementsScreen: View {
    @Environment(AppState.self) private var app

    private var items: [Achievement] { app.achievements }
    private var unlocked: Int { items.filter(\.isUnlocked).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(unlocked) / \(items.count) 已解锁")
                .font(.title2.weight(.bold))
            Text("只给你自己看，不算排行榜。约成、过夜、留照片都会慢慢点亮。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22, shadowRadius: 10)
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(achievement.tint.opacity(achievement.isUnlocked ? 0.22 : 0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? achievement.tint : Color.secondary)
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
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .glassCard(cornerRadius: 20, shadowRadius: 8)
        .opacity(achievement.isUnlocked ? 1 : 0.72)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title)，\(achievement.detail)，\(achievement.progressText)")
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
                Text("成就")
                    .font(.headline)
                if let next {
                    Text("已解锁 \(unlocked.count)/\(achievements.count) · 下一个：\(next.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if unlocked.isEmpty {
                    Text("记下第一个她，就开始点亮")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("全部点亮了，真可以")
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
