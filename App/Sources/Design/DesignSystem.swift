import SwiftUI

/// Shared proportions keep the content layer quiet and the controls tactile.
enum AstraLayout {
    static let pageInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 24
    static let contentWidth: CGFloat = 760
}

enum AstraMotion {
    static func response(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    static func press(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.78)
    }
}

/// An opaque, adaptive content surface. Glass belongs to the controls above it.
private struct ContentSurface: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Palette.surface, in: shape)
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(contrast == .increased ? 0.28 : (colorScheme == .dark ? 0.09 : 0.035)),
                    lineWidth: contrast == .increased ? 1 : 0.5
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.025), radius: 16, y: 6)
    }
}

/// SF Symbols sit on a softly lit, concentric tile; no bitmap or font dependency.
struct SymbolTile: View {
    let systemImage: String
    var tint: Color = Palette.accent
    var size: CGFloat = 44
    var filled = false
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
struct AstraMark: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle().strokeBorder(.primary.opacity(0.10), lineWidth: 0.75)
            Circle().trim(from: 0.05, to: 0.72)
                .stroke(.primary.opacity(0.22), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
                .rotationEffect(.degrees(-65))
                .padding(size * 0.13)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.44, weight: .light))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct SettingsIconLabelStyle: LabelStyle {
    var tint: Color = Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
            .onAppear {
                guard !appeared else { return }
                withAnimation(AstraMotion.response(reduceMotion: reduceMotion).delay(reduceMotion ? 0 : delay)) {
                    appeared = true
                }
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

    func astraListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
    }
}
