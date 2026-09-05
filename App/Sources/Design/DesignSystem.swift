import SwiftUI

/// Shared rhythm. Content is bounded on iPad while controls remain at native size.
enum AstraLayout {
    static let gutter: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let contentWidth: CGFloat = 840
    static let cornerRadius: CGFloat = 24
}

struct SurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = AstraLayout.cornerRadius
    func body(content: Content) -> some View {
        content
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.hairline.opacity(0.65), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func astraSurface(cornerRadius: CGFloat = AstraLayout.cornerRadius) -> some View {
        modifier(SurfaceModifier(cornerRadius: cornerRadius))
    }

    func astraListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .listSectionSpacing(20)
    }

    func astraContentMargins() -> some View {
        self
            .frame(maxWidth: AstraLayout.contentWidth)
            .frame(maxWidth: .infinity)
    }
}

/// Short editorial headings, with real content taking priority over decoration.
struct PageMasthead: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.medium).monospaced())
                .tracking(2.8)
                .foregroundStyle(Palette.accent)
            Text(title)
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct PrimaryActionLabel: View {
    let title: String
    var systemImage = "plus"
    var onDark = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .foregroundStyle(onDark ? Palette.midnight : Palette.background)
            .background(onDark ? Palette.gold : Palette.ink,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct QuietMetric: View {
    let value: String
    let label: String
    var onDark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(.title, design: .serif).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(onDark ? .white : Palette.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(onDark ? .white.opacity(0.7) : Palette.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A small engraved orbital mark, built as vector geometry for native rendering.
struct AstraMark: View {
    var color: Color = Palette.gold
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.4), lineWidth: 0.7)
            Ellipse().stroke(color.opacity(0.7), lineWidth: 0.7)
                .frame(width: 23).rotationEffect(.degrees(35))
            Image(systemName: "sparkle")
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(color)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
