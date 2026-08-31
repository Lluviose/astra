import SwiftUI

/// 记下新猎获后弹出的成就册翻页。
struct UnlockOverlay: View {
    let achievements: [Achievement]
    var onKeep: () -> Void
    var onOpenBook: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture { onKeep() }

            VStack(spacing: 16) {
                Text(achievements.count == 1 ? "成就册翻了一页" : "成就册翻了 \(achievements.count) 页")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                let shown = Array(achievements.prefix(3))
                ForEach(shown) { achievement in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(achievement.tint.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: achievement.symbolName)
                                .foregroundStyle(achievement.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.title)
                                .font(.headline)
                            Text(achievement.story)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(achievement.tier.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(achievement.tier.tint)
                    }
                }

                if achievements.count > 3 {
                    Text("还有 \(achievements.count - 3) 个，去成就册看")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button("收下", action: onKeep)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassCard(cornerRadius: 14, interactive: true, shadowRadius: 6)

                    Button("去成就册", action: onOpenBook)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.coral.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
            .padding(20)
            .glassCard(cornerRadius: 28, shadowRadius: 18)
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                appeared = true
            }
        }
    }
}
