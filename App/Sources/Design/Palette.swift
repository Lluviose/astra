import SwiftUI

/// 全局配色。主色是偏暖的珊瑚红，热力色带从天青过渡到珊瑚红。
enum Palette {

    static let accent = Color(red: 0.98, green: 0.33, blue: 0.42)
    static let accentDeep = Color(red: 0.86, green: 0.20, blue: 0.34)
    static let ink = Color.primary
    static let subtle = Color.secondary

    // MARK: - 热力色带

    private static let heatStops: [(r: Double, g: Double, b: Double)] = [
        (0.38, 0.70, 0.88),  // 天青 —— 人少
        (0.34, 0.79, 0.69),  // 薄荷
        (0.98, 0.78, 0.34),  // 琥珀
        (0.99, 0.55, 0.33),  // 蜜橙
        (0.98, 0.31, 0.42),  // 珊瑚 —— 最热
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
        [Color(red: 1.00, green: 0.55, blue: 0.52), Color(red: 0.98, green: 0.31, blue: 0.45)],
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
