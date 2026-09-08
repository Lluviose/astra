import SwiftUI

/// 记下新猎获后弹出的成就册翻页。
struct UnlockOverlay: View {
    let achievements: [Achievement]
    var onKeep: () -> Void
    var onOpenBook: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

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
                        SymbolTile(systemImage: achievement.symbolName, tint: achievement.tint, size: 44)
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

                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Button(action: onKeep) {
                        Text("收下")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .glassCard(cornerRadius: 16, interactive: true, shadowRadius: 4)
                    }
                    Button(action: onOpenBook) {
                        Text("去成就册")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Palette.accentDeep, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(24)
            .contentSurface(cornerRadius: 28)
            .frame(maxWidth: 440)
            .padding(.horizontal, 28)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(AstraMotion.response(reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }
}

