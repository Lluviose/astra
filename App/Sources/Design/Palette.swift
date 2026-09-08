import SwiftUI
import UIKit

/// Adaptive system neutrals, a single blue accent, and restrained midnight covers.
enum Palette {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = adaptive(light: 0x0066CC, dark: 0x409CFF)
    static let accentDeep = Color(red: 0.04, green: 0.25, blue: 0.50)
    static let coral = adaptive(light: 0xB84462, dark: 0xF18BA5)
    static let safe = adaptive(light: 0x247867, dark: 0x6AD2BA)
    static let warning = adaptive(light: 0x9C5B0B, dark: 0xF4BA64)
    static let gold = Color(red: 0.93, green: 0.82, blue: 0.57)
    static let goldDeep = adaptive(light: 0x876322, dark: 0xDFC389)
    static let midnight = Color(red: 0.055, green: 0.075, blue: 0.12)

    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.14, blue: 0.22),
                 Color(red: 0.17, green: 0.22, blue: 0.33),
                 Color(red: 0.24, green: 0.30, blue: 0.42)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let velvetGradient = LinearGradient(
        colors: [Color(red: 0.11, green: 0.12, blue: 0.19),
                 Color(red: 0.22, green: 0.22, blue: 0.31),
                 Color(red: 0.32, green: 0.29, blue: 0.39)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let screenGradient = LinearGradient(
        colors: [background, background],
        startPoint: .top, endPoint: .bottom
    )

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xff) / 255,
                           green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
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

    static func avatarColors(_ index: Int) -> [Color] {
        // `abs(Int.min)` 会溢出并触发运行时崩溃；导入数据即使异常也应稳定回退到调色板。
        let remainder = index % avatarGradients.count
        let safeIndex = remainder >= 0 ? remainder : remainder + avatarGradients.count
        return avatarGradients[safeIndex]
    }

    static func avatarGradient(_ index: Int) -> LinearGradient {
        LinearGradient(colors: avatarColors(index), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 档案页 hero：把她的头像色压暗，做成一张属于她的封面。
    static func dossierGradient(_ index: Int) -> LinearGradient {
        let colors = avatarColors(index)
        return LinearGradient(
            colors: [
                midnight.mix(with: colors[0], by: 0.24),
                midnight.mix(with: colors[1], by: 0.36),
                midnight.mix(with: colors[0], by: 0.46),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

