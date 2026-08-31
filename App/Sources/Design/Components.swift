import SwiftUI

// MARK: - 流式布局

/// 标签自动换行。用 SwiftUI Layout 协议实现，比嵌套 HStack 稳定得多。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if projected > maxWidth, !current.indices.isEmpty {
                result.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = projected
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { result.append(current) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let intrinsicWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? intrinsicWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}

// MARK: - 头像

struct AvatarView: View {
    let text: String
    let paletteIndex: Int
    var size: CGFloat = 46
    /// 外圈描边颜色，用来表达相处状态
    var ringColor: Color?
    var isDimmed: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(Palette.avatarGradient(paletteIndex))

            // 顶部内高光，让圆片看起来像一颗玻璃珠
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Text(text)
                .font(.system(size: size * 0.40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, size * 0.1)
        }
        .frame(width: size, height: size)
        .saturation(isDimmed ? 0.25 : 1)
        .overlay {
            Circle().strokeBorder(.white.opacity(0.32), lineWidth: max(0.8, size * 0.022))
        }
        .overlay {
            if let ringColor {
                Circle()
                    .strokeBorder(ringColor, lineWidth: max(1.6, size * 0.05))
                    .padding(-max(2.4, size * 0.06))
            }
        }
        .shadow(color: .black.opacity(0.14), radius: size * 0.12, y: size * 0.05)
        .accessibilityHidden(true)
    }
}

extension AvatarView {
    init(companion: Companion, size: CGFloat = 46, showRing: Bool = true) {
        self.init(
            text: companion.initial,
            paletteIndex: companion.paletteIndex,
            size: size,
            ringColor: showRing ? companion.stage.tint : nil,
            isDimmed: companion.isArchived
        )
    }
}

// MARK: - 标签 / Chip

struct GlassChip: View {
    let title: String
    var systemImage: String?
    var isOn: Bool = false
    var tint: Color = Palette.accent
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            label
        }
        .buttonStyle(HapticButtonStyle(cue: isOn ? .toggleOff : .toggleOn))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // 选中态用实色胶囊（保证对比度），未选中态才是玻璃
    @ViewBuilder
    private var label: some View {
        let base = HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
            }
            Text(title)
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 6 : 9)

        if isOn {
            base
                .foregroundStyle(.white)
                .background { Capsule(style: .continuous).fill(tint.gradient) }
                .shadow(color: tint.opacity(0.35), radius: 8, y: 3)
        } else {
            base
                .foregroundStyle(Color.primary)
                .glassCapsule(interactive: true, shadowRadius: 8)
        }
    }
}

/// 只读标签
struct TagLabel: View {
    let title: String
    var systemImage: String?
    var tint: Color = .secondary
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            }
            Text(title).font(.caption.weight(.medium))
        }
        .foregroundStyle(filled ? .white : tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(filled ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.14)))
        }
    }
}

struct StageBadge: View {
    let stage: RelationStage
    var filled: Bool = false

    var body: some View {
        TagLabel(title: stage.label, systemImage: stage.symbolName, tint: stage.tint, filled: filled)
    }
}

// MARK: - 默契度

struct RatingStars: View {
    let rating: Int
    var size: CGFloat = 11
    var tint: Color = Color(red: 0.98, green: 0.72, blue: 0.24)

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rating ? tint : Color.secondary.opacity(0.35))
            }
        }
        .accessibilityLabel("默契度 \(rating) 星")
    }
}

/// 可交互的五星选择器
struct RatingPicker: View {
    @Binding var rating: Int
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { index in
                Button {
                    Haptics.shared.play(.selection)
                    rating = (rating == index) ? index - 1 : index
                } label: {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.system(size: size))
                        .foregroundStyle(
                            index <= rating
                                ? Color(red: 0.98, green: 0.72, blue: 0.24)
                                : Color.secondary.opacity(0.35)
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index) 星")
            }
        }
    }
}

// MARK: - 小部件

struct StatTile: View {
    let value: String
    let caption: String
    var systemImage: String?
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.semibold))
                }
                Text(caption).font(.caption)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 20, shadowRadius: 10)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.55))
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle) {
                    Haptics.shared.play(.lightTap)
                    action()
                }
                .glassActionStyle(prominent: true)
                .tint(Palette.accent)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

/// 玻璃圆形图标按钮（地图悬浮控件用）
struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 44
    var tint: Color?
    var isActive: Bool = false
    var cue: HapticCue = .lightTap
    var accessibilityText: String
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : (tint ?? Color.primary))
                .frame(width: size, height: size)
                .background {
                    if isActive { Circle().fill((tint ?? Palette.accent).gradient) }
                }
                .glassCircle(interactive: true)
                .contentShape(Circle())
        }
        .buttonStyle(HapticButtonStyle(cue: cue, scale: 0.92))
        .accessibilityLabel(accessibilityText)
    }
}
