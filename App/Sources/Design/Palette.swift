import SwiftUI

/// 全局配色。以夜紫为底、霓虹莓红为强调，保持私密、克制而不冷淡。
enum Palette {

    static let accent = Color(red: 0.72, green: 0.31, blue: 0.95)
    static let accentDeep = Color(red: 0.49, green: 0.16, blue: 0.78)
    static let coral = Color(red: 0.96, green: 0.29, blue: 0.50)
    static let safe = Color(red: 0.22, green: 0.70, blue: 0.56)
    static let warning = Color(red: 0.95, green: 0.48, blue: 0.28)
    static let midnight = Color(red: 0.06, green: 0.045, blue: 0.12)
    static let ink = Color.primary
    static let subtle = Color.secondary

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.17, green: 0.08, blue: 0.31),
            Color(red: 0.41, green: 0.12, blue: 0.46),
            Color(red: 0.69, green: 0.17, blue: 0.40),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenGradient = LinearGradient(
        colors: [accent.opacity(0.09), coral.opacity(0.035), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 热力色带

    private static let heatStops: [(r: Double, g: Double, b: Double)] = [
        (0.37, 0.68, 0.89),  // 雾蓝 —— 人少
        (0.35, 0.72, 0.69),  // 薄荷
        (0.58, 0.42, 0.92),  // 夜紫
        (0.82, 0.29, 0.72),  // 洋红
        (0.96, 0.29, 0.50),  // 莓红 —— 最热
    ]

    /// - Parameter t: 0...1 的热度比例
    static func heat(_ t: Double) -> Color {
        let clamped = min(max(t, 0), 1)
        let scaled = clamped * Double(heatStops.count - 1)
        let lower = min(Int(scaled), heatStops.count - 1)
        let upper = min(lower + 1, heatStops.count - 1)
        let f = scaled - Double(lower)
        let a = heatStops[lower]
        let b = heatStops[upper]
        return Color(
            red: a.r + (b.r - a.r) * f,
            green: a.g + (b.g - a.g) * f,
            blue: a.b + (b.b - a.b) * f
        )
    }

    // MARK: - 头像渐变

    static let avatarGradients: [[Color]] = [
        [Color(red: 0.93, green: 0.43, blue: 0.70), Color(red: 0.68, green: 0.27, blue: 0.94)],
        [Color(red: 0.55, green: 0.78, blue: 1.00), Color(red: 0.35, green: 0.48, blue: 0.95)],
        [Color(red: 0.62, green: 0.90, blue: 0.75), Color(red: 0.24, green: 0.72, blue: 0.60)],
        [Color(red: 1.00, green: 0.84, blue: 0.50), Color(red: 0.97, green: 0.60, blue: 0.24)],
        [Color(red: 0.83, green: 0.71, blue: 1.00), Color(red: 0.56, green: 0.42, blue: 0.94)],
        [Color(red: 1.00, green: 0.72, blue: 0.86), Color(red: 0.92, green: 0.42, blue: 0.72)],
        [Color(red: 0.66, green: 0.86, blue: 0.96), Color(red: 0.28, green: 0.64, blue: 0.82)],
        [Color(red: 0.96, green: 0.79, blue: 0.66), Color(red: 0.78, green: 0.53, blue: 0.38)],
    ]

    static func avatarGradient(_ index: Int) -> LinearGradient {
        let colors = avatarGradients[abs(index) % avatarGradients.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

}

extension ShapeStyle where Self == Color {
    static var brand: Color { Palette.accent }
}
