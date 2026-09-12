import SwiftUI

// MARK: - Liquid Glass 适配层
//
// iOS 26 引入了 Liquid Glass：`.glassEffect(_:in:)`、`GlassEffectContainer`、
// `.buttonStyle(.glass / .glassProminent)`。这些 API 只存在于 iOS 26 SDK。
//
// 本 App 最低支持 iOS 18，所以把全部玻璃调用收敛到这一个文件里，双重护栏：
//   1. `#if compiler(>=6.2)` —— 让 Xcode 16（无 iOS 26 SDK）也能编译通过；
//   2. `if #available(iOS 26.0, *)` —— 运行在 iOS 18 上时降级为 Material。

// MARK: - 运行时判断

enum LiquidGlass {
    /// 当前设备是否真的在跑 iOS 26 Liquid Glass。给需要在玻璃与实色之间切换排版的视图用。
    static var isAvailable: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return true }
        return false
        #else
        return false
        #endif
    }
}

// MARK: - 玻璃背景

struct LiquidGlassModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    let shape: S
    var tint: Color?
    var interactive: Bool
    var fallbackMaterial: Material
    var strokeOpacity: Double
    var shadowRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background {
                shape.fill(Palette.surface)
                    .overlay { shape.fill(tint?.opacity(0.12) ?? .clear) }
                    .overlay { shape.strokeBorder(Color.primary.opacity(0.24), lineWidth: 1) }
            }
        } else {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                applyLiquidGlass(content)
            } else {
                fallbackBody(content)
            }
            #else
            fallbackBody(content)
            #endif
        }
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    @ViewBuilder
    private func applyLiquidGlass(_ content: Content) -> some View {
        // 官方链式 API：.glassEffect(.regular.tint(.orange).interactive(), in: shape)
        // 四分支写开，避免在 ViewBuilder 里做 `var glass = ...` 赋值
        if let tint, interactive {
            content.glassEffect(.regular.tint(tint).interactive(), in: shape)
        } else if let tint {
            content.glassEffect(.regular.tint(tint), in: shape)
        } else if interactive {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
    #endif

    @ViewBuilder
    private func fallbackBody(_ content: Content) -> some View {
        content.background { fallbackGlass }
    }

    /// 拆成独立计算属性，避免整条链式表达式超出类型检查器的复杂度上限
    private var fallbackGlass: some View {
        let highlight = LinearGradient(
            colors: [
                .white.opacity(strokeOpacity * 1.8),
                .white.opacity(strokeOpacity * 0.4),
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        return shape
            .fill(fallbackMaterial)
            .overlay { shape.fill(tint?.opacity(0.22) ?? .clear) }
            .overlay { shape.strokeBorder(highlight, lineWidth: 0.8) }
            .compositingGroup()
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.06), radius: shadowRadius, y: shadowRadius * 0.35)
    }
}

/// `GlassEffectContainer` 的适配壳：iOS 26 上让相邻玻璃控件互相「融合」，
/// 低版本上直接透传内容。
struct GlassStack<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct GlassActionStyleModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // .glass 与 .glassProminent 是不同的 PrimitiveButtonStyle，
            // 不能走 `prominent ? .glassProminent : .glass` 三元（会被推断成 ButtonStyle）
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            legacy(content)
        }
        #else
        legacy(content)
        #endif
    }

    private func legacy(_ content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(prominent ? AnyShapeStyle(Palette.accentDeep.gradient) : AnyShapeStyle(Color.primary.opacity(0.10)))
            }
            .foregroundStyle(prominent ? .white : Color.primary)
    }
}

/// iOS 26 上让 Tab Bar 随滚动收起，低版本忽略
private struct MinimizableTabBarModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(typeSize.isAccessibilitySize || reduceMotion ? .never : .onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - View 扩展

extension View {

    /// 任意可内描边形状的玻璃背景
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        fallback: Material = .regularMaterial,
        strokeOpacity: Double = 0.18,
        shadowRadius: CGFloat = 10
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                shape: shape,
                tint: tint,
                interactive: interactive,
                fallbackMaterial: fallback,
                strokeOpacity: strokeOpacity,
                shadowRadius: shadowRadius
            )
        )
    }

    /// 胶囊玻璃（工具条、标签、悬浮按钮最常用）
    func glassCapsule(
        tint: Color? = nil,
        interactive: Bool = true,
        shadowRadius: CGFloat = 12
    ) -> some View {
        liquidGlass(in: Capsule(style: .continuous), tint: tint, interactive: interactive, shadowRadius: shadowRadius)
    }

    /// 圆角矩形玻璃卡片
    func glassCard(
        cornerRadius: CGFloat = 26,
        tint: Color? = nil,
        interactive: Bool = false,
        shadowRadius: CGFloat = 12
    ) -> some View {
        liquidGlass(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive,
            shadowRadius: shadowRadius
        )
    }

    /// 圆形玻璃（图标按钮）
    func glassCircle(tint: Color? = nil, interactive: Bool = true) -> some View {
        liquidGlass(in: Circle(), tint: tint, interactive: interactive, shadowRadius: 10)
    }

    /// 玻璃按钮样式（低版本降级为 bordered / borderedProminent）
    func glassActionStyle(prominent: Bool = false) -> some View {
        modifier(GlassActionStyleModifier(prominent: prominent))
    }

    func minimizableTabBar() -> some View {
        modifier(MinimizableTabBarModifier())
    }

    /// 深色渐变封面上的半透明按钮：iOS 26 走真玻璃，低版本用白色半透明 + 描边。
    func heroGlass(cornerRadius: CGFloat = 14, prominent: Bool = false) -> some View {
        modifier(HeroGlassModifier(cornerRadius: cornerRadius, prominent: prominent))
    }
}

private struct HeroGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let cornerRadius: CGFloat
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if prominent {
            content.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(.white)
            }
        } else if reduceTransparency || contrast == .increased {
            content.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.midnight)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                    }
            }
        } else if LiquidGlass.isAvailable {
            content.liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: true,
                shadowRadius: 0
            )
            .environment(\.colorScheme, .dark)
        } else {
            content.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.13))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                    }
            }
        }
    }
}

