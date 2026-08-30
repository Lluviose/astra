import SwiftUI

// MARK: - Liquid Glass 适配层
//
// iOS 26 引入了 Liquid Glass：`.glassEffect(_:in:)`、`GlassEffectContainer`、
// `.glassEffectID(_:in:)`、`.buttonStyle(.glass)`。这些 API 只存在于 iOS 26 SDK。
//
// 本 App 最低支持 iOS 18，所以把全部玻璃调用收敛到这一个文件里，双重护栏：
//   1. `#if compiler(>=6.2)` —— 让 Xcode 16（无 iOS 26 SDK）也能编译通过；
//   2. `if #available(iOS 26.0, *)` —— 运行在 iOS 18/25 上时降级为 Material。
//
// 降级方案不是简单的半透明色块：Material + 高光描边 + 柔和投影，
// 在视觉层级上尽量接近真玻璃，不至于让老系统看起来像另一个 App。

// MARK: - 玻璃背景

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive: Bool
    var fallbackMaterial: Material
    var strokeOpacity: Double
    var shadowRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            var glass = Glass.regular
            if let tint { glass = glass.tint(tint) }
            if interactive { glass = glass.interactive() }
            content.glassEffect(glass, in: shape)
        } else {
            fallbackBody(content)
        }
        #else
        fallbackBody(content)
        #endif
    }

    @ViewBuilder
    private func fallbackBody(_ content: Content) -> some View {
        content
            .background {
                shape
                    .fill(fallbackMaterial)
                    .overlay {
                        shape.fill(tint?.opacity(0.22) ?? .clear)
                    }
                    .overlay {
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(strokeOpacity * 2.2),
                                        .white.opacity(strokeOpacity * 0.4),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    }
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.16), radius: shadowRadius, y: shadowRadius * 0.45)
            }
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
            // .glass 与 .glassProminent 都是 GlassButtonStyle，仅配置不同，分支类型一致
            content.buttonStyle(prominent ? .glassProminent : .glass)
        } else {
            legacy(content)
        }
        #else
        legacy(content)
        #endif
    }

    // 低版本降级：两分支统一走同一种 buttonStyle + 条件化配色，
    // 避免 .bordered / .borderedProminent 具体类型不同导致分支无法合一
    private func legacy(_ content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(prominent ? AnyShapeStyle(Palette.accent.gradient) : AnyShapeStyle(Color.primary.opacity(0.10)))
            }
            .foregroundStyle(prominent ? .white : Color.primary)
    }
}

/// iOS 26 上让 Tab Bar 随滚动收起，低版本忽略
private struct MinimizableTabBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
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

    /// 任意形状的玻璃背景
    func liquidGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        fallback: Material = .ultraThinMaterial,
        strokeOpacity: Double = 0.18,
        shadowRadius: CGFloat = 14
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
        shadowRadius: CGFloat = 18
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
}
