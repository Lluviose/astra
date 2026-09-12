import SwiftUI

/// 记下新猎获后弹出的成就册翻页。
struct UnlockOverlay: View {
    let achievements: [Achievement]
    var onKeep: () -> Void
    var onOpenBook: () -> Void

    @State private var appeared = false
    @State private var bounce = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var shown: [Achievement] { Array(achievements.prefix(3)) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { onKeep() }

            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text(achievements.count == 1 ? "成就册翻了一页" : "成就册翻了 \(achievements.count) 页")
                        .font(.headline)
                    Text("按你自己的记录点亮，只给你看。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, achievement in
                        HStack(spacing: 12) {
                            Medallion(
                                systemImage: achievement.symbolName,
                                tint: achievement.tint,
                                ring: achievement.tier.tint,
                                size: 48,
                                bounceTrigger: bounce
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(achievement.story)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            TagLabel(title: "\(achievement.tier.label)徽章", tint: achievement.tier.tint, filled: true)
                        }
                        .padding(12)
                        .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .entranceMotion(delay: 0.08 + AstraMotion.stagger(index, step: 0.07))
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
                        SurfaceButtonLabel(title: "收下", systemImage: "checkmark")
                    }
                    Button(action: onOpenBook) {
                        SurfaceButtonLabel(title: "去成就册", systemImage: "medal.fill", prominent: true)
                    }
                }
                .buttonStyle(HapticButtonStyle())
            }
            .padding(22)
            .contentSurface(cornerRadius: 28)
            .frame(maxWidth: 440)
            .padding(.horizontal, 28)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(AstraMotion.emphasis(reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(420))
            bounce += 1
        }
    }
}
