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

    private func measuredSize(of subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return subview.sizeThatFits(ProposedViewSize(width: max(0, min(ideal.width, maxWidth)), height: nil))
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = measuredSize(of: subviews[index], maxWidth: maxWidth)
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
                let size = measuredSize(of: subviews[index], maxWidth: bounds.width)
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

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(text)
                    .font(.system(size: size * 0.40, weight: .semibold, design: .rounded))
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
                    .strokeBorder(
                        AngularGradient(
                            colors: [ringColor, ringColor.opacity(0.55), ringColor],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: max(1.6, size * 0.05)
                    )
                    .padding(-max(2.4, size * 0.06))
            }
        }
        .shadow(color: .black.opacity(0.14), radius: size * 0.12, y: size * 0.05)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(AstraMotion.response(reduceMotion: reduceMotion)) { action() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark" : (systemImage ?? "circle"))
                    .font(.caption.weight(.semibold))
                    .frame(width: 14)
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                Text(title)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(isOn ? tint : Color.primary)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(isOn ? tint.opacity(0.12) : Palette.surface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isOn ? tint.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 0.75)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(HapticButtonStyle(cue: isOn ? .toggleOff : .toggleOn))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
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

// MARK: - 分段胶囊选择器

struct PillOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var systemImage: String? = nil
    var detail: String? = nil
    var tint: Color? = nil

    var id: Value { value }
}

/// A row of capsules with one sliding, filled selection. Replaces tinted-chip pickers.
struct PillPicker<Value: Hashable>: View {
    let options: [PillOption<Value>]
    @Binding var selection: Value
    var tint: Color = Palette.accent
    var scrollable = true
    var fillsWidth = false
    var cue: HapticCue = .selection

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if scrollable {
            ScrollView(.horizontal, showsIndicators: false) {
                row
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                pill(option)
            }
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil)
    }

    private func pill(_ option: PillOption<Value>) -> some View {
        let isOn = option.value == selection
        let fill = option.tint ?? tint
        return Button {
            guard !isOn else { return }
            withAnimation(AstraMotion.response(reduceMotion: reduceMotion)) {
                selection = option.value
            }
        } label: {
            HStack(spacing: 5) {
                if let systemImage = option.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                }
                Text(option.title)
                if let detail = option.detail {
                    Text(detail)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .opacity(0.72)
                }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 36)
            .background {
                if isOn {
                    Capsule(style: .continuous)
                        .fill(fill.gradient)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .background(Palette.surface, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(isOn ? 0 : 0.08), lineWidth: 0.5)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(HapticButtonStyle(cue: cue, scale: 0.96))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - 进度条

/// A thin capsule meter with a springing fill and a small highlight at its tip.
struct MeterBar: View {
    var value: Double
    var tint: Color = Palette.accent
    var height: CGFloat = 6
    var onDark = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: CGFloat {
        let safe = value.isFinite ? value : 0
        return CGFloat(min(max(safe, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(onDark ? Color.white.opacity(0.16) : tint.opacity(0.12))
                Capsule()
                    .fill(onDark ? AnyShapeStyle(Color.white) : AnyShapeStyle(tint.gradient))
                    .frame(width: max(fraction > 0 ? height : 0, proxy.size.width * fraction))
                    .overlay(alignment: .trailing) {
                        if fraction > 0, fraction < 1 {
                            Circle()
                                .fill(.white.opacity(onDark ? 0.9 : 0.6))
                                .frame(width: max(2, height - 3), height: max(2, height - 3))
                                .padding(.trailing, 1.5)
                        }
                    }
            }
        }
        .frame(height: height)
        .animation(AstraMotion.settle(reduceMotion: reduceMotion), value: fraction)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((Double(fraction) * 100).rounded()))%"))
    }
}

// MARK: - 徽章

/// A medallion for achievements: a tinted disc, a tier ring, and a lock when it is still dark.
struct Medallion: View {
    let systemImage: String
    var tint: Color
    var ring: Color
    var size: CGFloat = 44
    var isLit = true
    /// Change this value to bounce the symbol once.
    var bounceTrigger = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(isLit ? AnyShapeStyle(tint.opacity(0.16)) : AnyShapeStyle(Color.secondary.opacity(0.10)))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(isLit ? 0.30 : 0.10), .clear],
                        center: UnitPoint(x: 0.35, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            ring.opacity(isLit ? 1 : 0.30),
                            ring.opacity(isLit ? 0.45 : 0.14),
                            ring.opacity(isLit ? 1 : 0.30),
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: max(1.2, size * 0.04)
                )
            Image(systemName: systemImage)
                .font(.system(size: size * 0.40, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isLit ? tint : Color.secondary)
                .symbolEffect(.bounce, value: bounceTrigger)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if !isLit {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(size * 0.07)
                    .background(Palette.surface, in: Circle())
                    .offset(x: size * 0.06, y: size * 0.06)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Hero 面板（首页 / 图鉴 / 成就册 / 排行共用）

/// The mesh behind a cover. Only the overview cover drifts, at a low frame rate, and it pauses
/// under Reduce Motion, Low Power Mode, or when the scene is not active.
struct CoverBackground: View {
    let style: CoverStyle
    var watermark: String? = nil
    var animated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var drifts: Bool {
        animated && !reduceMotion && scenePhase == .active && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if drifts {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                    mesh(phase: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                mesh(phase: 0)
            }
            decoration
        }
    }

    private func mesh(phase: TimeInterval) -> some View {
        let cycle = phase.truncatingRemainder(dividingBy: 14) / 14 * 2 * Double.pi
        let dx = Float(sin(cycle)) * 0.07
        let dy = Float(cos(cycle * 0.8)) * 0.06
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5 + dx, 0.5 + dy], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: style.meshColors,
            smoothsColors: true
        )
    }

    private var decoration: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
            ZStack {
                Circle().strokeBorder(.white.opacity(0.09), lineWidth: 0.75)
                Circle().strokeBorder(.white.opacity(0.05), lineWidth: 0.75).padding(28)
                Circle()
                    .fill(.white.opacity(0.4))
                    .frame(width: 4, height: 4)
                    .offset(y: -110)
                if let watermark {
                    Image(systemName: watermark)
                        .font(.system(size: 66, weight: .ultraLight))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.07))
                }
            }
            .frame(width: 220, height: 220)
            .offset(x: 70, y: -100)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A single quiet cover anchors each page; decorative rings stay behind content.
struct HeroPanel<Content: View>: View {
    var cover: CoverStyle = .midnight
    var cornerRadius: CGFloat = AstraLayout.coverRadius
    var watermark: String? = nil
    var padding: CGFloat = 24
    var animated = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background {
                CoverBackground(style: cover, watermark: watermark, animated: animated)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0.04)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .shadow(color: cover.glow.opacity(0.22), radius: 22, y: 12)
            .shadow(color: .black.opacity(0.06), radius: 1, y: 0.5)
            .environment(\.colorScheme, .dark)
            .accessibilityElement(children: .contain)
    }
}

/// hero 里的一格数字
struct HeroMetric: View {
    let value: String
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

/// hero 左上角的小胶囊，如「只在这台手机上」
struct HeroBadge: View {
    let title: String
    var systemImage: String = "lock.shield.fill"

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
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
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .heroGlass(cornerRadius: 18, prominent: prominent)
            .foregroundStyle(prominent ? Palette.accentDeep : .white)
    }
}

/// A full-width action on a light surface: filled for the primary, tinted for the secondary.
struct SurfaceButtonLabel: View {
    let title: String
    let systemImage: String
    var prominent: Bool = false
    var tint: Color = Palette.accent

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 12)
            .foregroundStyle(prominent ? Color.white : tint)
            .background {
                if prominent {
                    shape.fill(tint.gradient)
                } else {
                    shape.fill(tint.opacity(0.10))
                }
            }
            .contentShape(shape)
    }
}

// MARK: - 玻璃卡片区块

/// A legible grouped content card with a consistent symbol and heading hierarchy.
struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = Palette.accent
    var cornerRadius: CGFloat = 22
    @Environment(\.dynamicTypeSize) private var typeSize
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    accessory
                }
            } else {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 4)
                    accessory
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .contentSurface(cornerRadius: cornerRadius)
    }

    private var heading: some View {
        HStack(spacing: 10) {
            SymbolTile(systemImage: systemImage, tint: tint, size: 32)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var accessory: some View {
        trailing()
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                SymbolTile(systemImage: systemImage, tint: tint, size: 46)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.05), in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .padding(18)
        .background(alignment: .topLeading) {
            RadialGradient(
                colors: [tint.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 150
            )
            .clipShape(RoundedRectangle(cornerRadius: AstraLayout.cardRadius, style: .continuous))
        }
        .contentSurface()
        .contentShape(RoundedRectangle(cornerRadius: AstraLayout.cardRadius, style: .continuous))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .contentTransition(reduceMotion ? .opacity : .numericText())
            }
            MeterBar(value: Double(count) / Double(max(peak, 1)), tint: tint, height: 7)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption.weight(.semibold))
                }
                Text(caption).font(.caption)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .contentSurface(cornerRadius: 22)
        .accessibilityElement(children: .combine)
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
    @State private var bounce = 0

    var body: some View {
        VStack(spacing: 12) {
            SymbolTile(systemImage: symbol, size: 68, bounceTrigger: bounce)
                .padding(.bottom, 8)
            Text(title).font(.title3.weight(.semibold))
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
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(260))
            bounce += 1
        }
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
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? (tint ?? Palette.accent) : Color.primary)
                .frame(width: max(44, size), height: max(44, size))
                .glassCircle(tint: isActive ? (tint ?? Palette.accent).opacity(0.18) : nil, interactive: true)
                .overlay(alignment: .bottomTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.accentDeep, Palette.surface)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(HapticButtonStyle(cue: cue, scale: 0.92))
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
