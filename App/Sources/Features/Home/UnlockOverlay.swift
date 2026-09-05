import SwiftUI

/// 记下新猎获后弹出的成就册翻页。
struct UnlockOverlay: View {
    let achievements: [Achievement]
    var onKeep: () -> Void
    var onOpenBook: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    Button(action: onKeep) {
                        Text("收下")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticButtonStyle())
                    .astraSurface(cornerRadius: 14)
                    .accessibilityIdentifier("dismiss-unlocks")

                    Button(action: onOpenBook) {
                        Text("去成就册")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(Palette.background)
                            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
            .padding(20)
            .astraSurface(cornerRadius: 28)
            .frame(maxWidth: 480)
            .padding(.horizontal, 28)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}
