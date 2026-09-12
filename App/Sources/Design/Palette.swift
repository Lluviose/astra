import SwiftUI
import UIKit

/// Adaptive system neutrals, a single blue accent, and restrained midnight covers.
enum Palette {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceRaised = Color(uiColor: .tertiarySystemGroupedBackground)
    static let accent = adaptive(light: 0x0066CC, dark: 0x409CFF)
    static let accentDeep = Color(red: 0.04, green: 0.25, blue: 0.50)
    static let coral = adaptive(light: 0xB84462, dark: 0xF18BA5)
    static let safe = adaptive(light: 0x247867, dark: 0x6AD2BA)
    static let warning = adaptive(light: 0x9C5B0B, dark: 0xF4BA64)
    static let iris = adaptive(light: 0x5E4FB3, dark: 0xA79BFF)
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

// MARK: - 封面

/// Each page owns one cover. A cover is a quiet 3 × 3 mesh; the hue is the page identity,
/// the content on top stays white and the decoration stays behind it.
enum CoverStyle: Hashable {
    /// Overview, statistics: deep blue.
    case midnight
    /// Gallery, scores: muted rose over indigo.
    case velvet
    /// Achievements, ranking: charcoal warmed toward gold.
    case gilded
    /// Statistics: deep teal.
    case tide
    /// A companion's own cover, derived from her avatar palette.
    case dossier(Int)

    /// Nine colors, row-major, for `MeshGradient(width: 3, height: 3)`.
    var meshColors: [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.08, green: 0.11, blue: 0.19), Color(red: 0.11, green: 0.16, blue: 0.27), Color(red: 0.18, green: 0.24, blue: 0.37),
                Color(red: 0.10, green: 0.14, blue: 0.23), Color(red: 0.16, green: 0.22, blue: 0.35), Color(red: 0.24, green: 0.31, blue: 0.45),
                Color(red: 0.13, green: 0.18, blue: 0.28), Color(red: 0.20, green: 0.27, blue: 0.40), Color(red: 0.29, green: 0.35, blue: 0.49),
            ]
        case .velvet:
            return [
                Color(red: 0.12, green: 0.10, blue: 0.19), Color(red: 0.18, green: 0.13, blue: 0.26), Color(red: 0.27, green: 0.18, blue: 0.34),
                Color(red: 0.15, green: 0.12, blue: 0.22), Color(red: 0.24, green: 0.17, blue: 0.31), Color(red: 0.34, green: 0.22, blue: 0.38),
                Color(red: 0.20, green: 0.15, blue: 0.27), Color(red: 0.30, green: 0.21, blue: 0.36), Color(red: 0.41, green: 0.27, blue: 0.42),
            ]
        case .gilded:
            return [
                Color(red: 0.11, green: 0.10, blue: 0.14), Color(red: 0.17, green: 0.15, blue: 0.18), Color(red: 0.27, green: 0.22, blue: 0.20),
                Color(red: 0.14, green: 0.12, blue: 0.16), Color(red: 0.24, green: 0.20, blue: 0.20), Color(red: 0.36, green: 0.29, blue: 0.22),
                Color(red: 0.19, green: 0.16, blue: 0.18), Color(red: 0.31, green: 0.25, blue: 0.21), Color(red: 0.45, green: 0.36, blue: 0.24),
            ]
        case .tide:
            return [
                Color(red: 0.06, green: 0.13, blue: 0.17), Color(red: 0.09, green: 0.19, blue: 0.24), Color(red: 0.14, green: 0.27, blue: 0.32),
                Color(red: 0.08, green: 0.16, blue: 0.21), Color(red: 0.13, green: 0.25, blue: 0.30), Color(red: 0.18, green: 0.34, blue: 0.38),
                Color(red: 0.11, green: 0.21, blue: 0.26), Color(red: 0.17, green: 0.31, blue: 0.35), Color(red: 0.24, green: 0.40, blue: 0.43),
            ]
        case .dossier(let index):
            let colors = Palette.avatarColors(index)
            let first = colors[0]
            let second = colors[1]
            let base = Palette.midnight
            return [
                base.mix(with: first, by: 0.20), base.mix(with: second, by: 0.26), base.mix(with: first, by: 0.36),
                base.mix(with: second, by: 0.24), base.mix(with: first, by: 0.34), base.mix(with: second, by: 0.44),
                base.mix(with: first, by: 0.30), base.mix(with: second, by: 0.40), base.mix(with: first, by: 0.50),
            ]
        }
    }

    /// The soft color that sits under the cover as its shadow.
    var glow: Color {
        switch self {
        case .midnight: Color(red: 0.16, green: 0.24, blue: 0.42)
        case .velvet: Color(red: 0.38, green: 0.20, blue: 0.36)
        case .gilded: Color(red: 0.36, green: 0.28, blue: 0.16)
        case .tide: Color(red: 0.12, green: 0.30, blue: 0.34)
        case .dossier(let index): Palette.avatarColors(index)[1]
        }
    }
}
