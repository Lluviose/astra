import SwiftUI
import UIKit

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
            let size = subviews[index].sizeThatFits(maxWidth.isFinite ? ProposedViewSize(width: maxWidth, height: nil) : .unspecified)
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
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
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
    var photoID: String? = nil
    var ignorePrivacyMask: Bool = false

    @Environment(AppState.self) private var app
    @State private var photo: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Palette.avatarGradient(paletteIndex))

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(text)
                    .font(.system(size: size * 0.40, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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

        .blur(radius: shouldObscure ? 8 : 0)
        .accessibilityHidden(true)
        .task(id: photoID) {
            photo = photoID.flatMap { MediaStore.image(id: $0) }
        }
    }

    private var shouldObscure: Bool {
        !ignorePrivacyMask && !app.namesRevealed && photoID != nil
    }
}

extension AvatarView {
    init(companion: Companion, size: CGFloat = 46, showRing: Bool = true, ignorePrivacyMask: Bool = false) {
        self.init(
            text: companion.initial,
            paletteIndex: companion.paletteIndex,
            size: size,
            ringColor: showRing ? companion.stage.tint : nil,
            isDimmed: companion.isArchived,
            photoID: companion.photoID,
            ignorePrivacyMask: ignorePrivacyMask
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
        .frame(minHeight: 44)

        if isOn {
            base
                .foregroundStyle(Palette.background)
                .background { Capsule(style: .continuous).fill(Palette.ink) }
        } else {
            base
                .foregroundStyle(Color.primary)
                .background(Palette.surfaceSecondary.opacity(0.65), in: Capsule())
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
        .foregroundStyle(filled ? Palette.background : tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(filled ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(tint.opacity(0.09)))
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

// MARK: - Hero 面板（首页 / 图鉴 / 成就册 / 排行共用）

/// Dark mineral covers with an engraved edge; the content carries the hierarchy.
struct HeroPanel<Content: View>: View {
    var gradient: LinearGradient = Palette.heroGradient
    var cornerRadius: CGFloat = AstraLayout.cornerRadius
    var glow: Color = Palette.accentDeep
    /// 传 SF Symbol 名就画成右上角水印，不传就用一枚柔光圆。
    var watermark: String? = nil
    var padding: CGFloat = 24
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(gradient, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            .accessibilityElement(children: .contain)
    }

}

/// hero 里的一格数字
struct HeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .serif).weight(.medium))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// hero 左上角的小胶囊，如「只在这台手机上」
struct HeroBadge: View {
    let title: String
    var systemImage: String = "lock.shield.fill"

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.75))
    }
}

/// hero 底部的横排按钮：`prominent` 是白底主按钮，否则是半透明副按钮。
struct HeroButton: View {
    let title: String
    let systemImage: String
    var prominent: Bool = false
    var cue: HapticCue = .lightTap
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HeroButtonLabel(title: title, systemImage: systemImage, prominent: prominent)
        }
        .buttonStyle(HapticButtonStyle(cue: cue, scale: 0.97))
    }
}

/// 给 Menu / NavigationLink 复用的 hero 按钮外观
struct HeroButtonLabel: View {
    let title: String
    let systemImage: String
    var prominent: Bool = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(.horizontal, 8)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.gold)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                        }
                }
            }
            .foregroundStyle(prominent ? Palette.midnight : .white)
    }
}

// MARK: - 玻璃卡片区块

/// 带一行标题的玻璃卡片。列表页大部分模块都长这样。
struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = Palette.accent
    var cornerRadius: CGFloat = 22
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        systemImage: String,
        tint: Color = Palette.accent,
        cornerRadius: CGFloat = 22,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.trailing = trailing
        self.content = content
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Label {
                    Text(title).foregroundStyle(Palette.ink)
                } icon: {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize { Spacer() }
                trailing()
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryInk)
            }
            VStack(alignment: .leading, spacing: 12) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .astraSurface(cornerRadius: cornerRadius)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SectionCard where Trailing == EmptyView {
    init(
        _ title: String,
        systemImage: String,
        tint: Color = Palette.accent,
        cornerRadius: CGFloat = 22,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title,
            systemImage: systemImage,
            tint: tint,
            cornerRadius: cornerRadius,
            trailing: { EmptyView() },
            content: content
        )
    }
}

/// 两格并排的入口砖：图标 + 标题 + 一行小字。
struct EntryTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(tint)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryInk)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(18)
        .astraSurface(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// 统计页的一根横向柱：标题 · 数字 · 比例条。
struct InsightBarRow: View {
    let title: String
    let count: Int
    let peak: Int
    var tint: Color = Palette.coral
    var systemImage: String?
    var trailing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(trailing ?? "\(count)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * min(1, max(0, CGFloat(count) / CGFloat(max(peak, 1)))))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(trailing ?? "\(count)")")
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
                .font(.system(.title2, design: .serif).weight(.medium))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .astraSurface(cornerRadius: 20)
    }
}

/// 行尾的灰色小箭头
struct ChevronHint: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
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
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Palette.accent)
                .frame(width: 80, height: 80)
                .background(Palette.surfaceSecondary, in: RoundedRectangle(cornerRadius: 26))
                .padding(.bottom, 8)
                .accessibilityHidden(true)
            Text(title).font(.system(.title2, design: .serif))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    PrimaryActionLabel(title: actionTitle)
                }
                .buttonStyle(HapticButtonStyle())
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
