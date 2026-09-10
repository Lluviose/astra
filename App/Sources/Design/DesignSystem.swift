import SwiftUI

/// Shared proportions keep the content layer quiet and the controls tactile.
enum AstraLayout {
    static let pageInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 24
    static let coverRadius: CGFloat = 30
    static let contentWidth: CGFloat = 760
}

/// One motion vocabulary: a press, a response, an emphasis, a settle.
enum AstraMotion {
    /// Screen / selection response.
    static func response(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// Press feedback on buttons and tiles.
    static func press(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.78)
    }

    /// Slightly slower, for covers and page-level reveals.
    static func emphasis(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.56, dampingFraction: 0.84)
    }

    /// A quick settle for meters, rings and numbers.
    static func settle(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.34, dampingFraction: 0.9)
    }

    /// Stagger delay for the n-th item, capped so long lists never feel slow.
    static func stagger(_ index: Int, step: Double = 0.045, cap: Double = 0.24) -> Double {
        min(Double(max(index, 0)) * step, cap)
    }
}

/// An opaque, adaptive content surface. Glass belongs to the controls above it.
private struct ContentSurface: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark
        content
            .background(Palette.surface, in: shape)
            .overlay {
                if isDark, contrast != .increased {
                    shape.inset(by: 0.5)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.10), .white.opacity(0.0)],
                                startPoint: .top, endPoint: .center
                            ),
                            lineWidth: 0.5
                        )
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(contrast == .increased ? 0.28 : (isDark ? 0.09 : 0.04)),
                    lineWidth: contrast == .increased ? 1 : 0.5
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(isDark ? 0.10 : 0.03), radius: 1, y: 0.5)
            .shadow(color: .black.opacity(isDark ? 0.14 : 0.035), radius: 18, y: 8)
    }
}

/// SF Symbols sit on a softly lit, concentric tile; no bitmap or font dependency.
struct SymbolTile: View {
    let systemImage: String
    var tint: Color = Palette.accent
    var size: CGFloat = 44
    var filled = false
    /// Change this value to bounce the symbol once.
    var bounceTrigger = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.43, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(filled ? .white : tint)
            .symbolEffect(.bounce, value: bounceTrigger)
            .frame(width: size, height: size)
            .background {
                shape.fill(filled ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(colorScheme == .dark ? 0.18 : 0.09)))
                    .overlay {
                        shape.fill(LinearGradient(
                            colors: [.white.opacity(filled ? 0.25 : 0.14), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    }
                    .overlay {
                        shape.strokeBorder(
                            filled ? Color.white.opacity(0.28) : tint.opacity(contrast == .increased ? 0.55 : 0.12),
                            lineWidth: 0.75
                        )
                    }
            }
            .accessibilityHidden(true)
    }
}

/// A restrained star motif, shared by the overview and app identity.
/// The orbit draws itself on first appearance and leaves a small planet at its end.
struct AstraMark: View {
    var size: CGFloat = 48
    var animated = true
    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var orbitRadius: CGFloat { size * 0.37 }

    var body: some View {
        ZStack {
            Circle().strokeBorder(.primary.opacity(0.10), lineWidth: 0.75)
            Circle().trim(from: 0.05, to: drawn || !animated ? 0.72 : 0.05)
                .stroke(.primary.opacity(0.22), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
                .rotationEffect(.degrees(-65))
                .padding(size * 0.13)
            Circle()
                .fill(.primary.opacity(0.55))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: -0.97 * orbitRadius, y: -0.245 * orbitRadius)
                .opacity(drawn || !animated ? 1 : 0)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.44, weight: .light))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard animated, !drawn else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.9, dampingFraction: 0.9).delay(0.12)) {
                drawn = true
            }
        }
    }
}

/// Settings rows use the system convention: a white glyph on a solid, rounded tint.
struct SettingsIconLabelStyle: LabelStyle {
    var tint: Color = Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7.5, style: .continuous))
                .accessibilityHidden(true)
            configuration.title
        }
        .padding(.vertical, 2)
    }
}

private struct EntranceMotion: ViewModifier {
    var delay: Double
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.985, anchor: .top)
            .onAppear {
                guard !appeared else { return }
                withAnimation(AstraMotion.emphasis(reduceMotion: reduceMotion).delay(reduceMotion ? 0 : delay)) {
                    appeared = true
                }
            }
    }
}

/// Cards ease in as they scroll into view. Reduce Motion keeps only the fade.
private struct ScrollReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let reduceMotion = reduceMotion
        return content.scrollTransition(.interactive(timingCurve: .easeInOut), axis: .vertical) { view, phase in
            view
                .opacity(phase.isIdentity ? 1 : 0.7)
                .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.975, anchor: phase.value < 0 ? .bottom : .top)
        }
    }
}

extension View {
    func contentSurface(cornerRadius: CGFloat = AstraLayout.cardRadius) -> some View {
        modifier(ContentSurface(cornerRadius: cornerRadius))
    }

    func entranceMotion(delay: Double = 0) -> some View {
        modifier(EntranceMotion(delay: delay))
    }

    func scrollReveal() -> some View {
        modifier(ScrollReveal())
    }

    /// Overscroll response for the first cover on a page: it grows a little and lags the pull.
    func coverStretch(pull: CGFloat) -> some View {
        let clamped = min(max(pull, 0), 140)
        return self
            .scaleEffect(1 + clamped / 1600, anchor: .top)
            .offset(y: -clamped * 0.18)
    }

    func astraListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
    }
}
