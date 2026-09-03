import SwiftUI

/// 全局配色。以夜紫为底、霓虹莓红为强调，保持私密、克制而不冷淡。
enum Palette {

    static let accent = Color(red: 0.72, green: 0.31, blue: 0.95)
    static let accentDeep = Color(red: 0.49, green: 0.16, blue: 0.78)
    static let coral = Color(red: 0.96, green: 0.29, blue: 0.50)
    static let safe = Color(red: 0.22, green: 0.70, blue: 0.56)
    static let warning = Color(red: 0.95, green: 0.48, blue: 0.28)
    /// 王冠、名次、金徽章
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.28)
    static let goldDeep = Color(red: 0.92, green: 0.63, blue: 0.12)
    static let midnight = Color(red: 0.06, green: 0.045, blue: 0.12)

    /// 首页、成就册、排行用的主 hero 渐变
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.17, green: 0.08, blue: 0.31),
            Color(red: 0.41, green: 0.12, blue: 0.46),
            Color(red: 0.69, green: 0.17, blue: 0.40),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 后宫图鉴、今夜焦点用的更深一档的渐变
    static let velvetGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.035, blue: 0.16),
            Color(red: 0.36, green: 0.07, blue: 0.30),
            Color(red: 0.78, green: 0.15, blue: 0.34),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenGradient = LinearGradient(
        colors: [accent.opacity(0.09), coral.opacity(0.035), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
                midnight.mix(with: colors[0], by: 0.42),
                midnight.mix(with: colors[1], by: 0.58),
                midnight.mix(with: colors[0], by: 0.80),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
