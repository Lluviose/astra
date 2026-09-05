import SwiftUI
import UIKit

/// Mineral neutrals with a restrained brass accent. Every reading surface adapts
/// to appearance; colors used on the dark covers intentionally remain fixed.
enum Palette {
    static let background = adaptive(0xF5F3EE, 0x171416)
    static let surface = adaptive(0xFFFEFA, 0x231E21)
    static let surfaceSecondary = adaptive(0xEAE7E0, 0x30282C)
    static let ink = adaptive(0x202928, 0xF0EDE6)
    static let secondaryInk = adaptive(0x626B67, 0xAEB8B2)
    static let hairline = adaptive(0xDADDD6, 0x44373C)
    static let accent = adaptive(0x7A5D35, 0xD5BA91)
    static let accentDeep = Color(hex: 0x50412D)
    static let coral = adaptive(0x97594F, 0xDBA396)
    static let safe = adaptive(0x436C5E, 0x93BBAA)
    static let warning = adaptive(0x8E602F, 0xD9B17E)
    static let gold = Color(hex: 0xDDC39A)
    static let goldDeep = adaptive(0x7A5D35, 0xDDC39A)
    static let midnight = Color(hex: 0x15201F)

    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x1C2A28), Color(hex: 0x35423B)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let velvetGradient = LinearGradient(
        colors: [Color(hex: 0x291A22), Color(hex: 0x50303D)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let screenGradient = LinearGradient(
        colors: [background, background], startPoint: .top, endPoint: .bottom
    )

    static let avatarGradients: [[Color]] = [
        [Color(hex: 0xB68E7E), Color(hex: 0x87695F)],
        [Color(hex: 0x8D9EAA), Color(hex: 0x5C727F)],
        [Color(hex: 0x8A9F8D), Color(hex: 0x5E7967)],
        [Color(hex: 0xB5A082), Color(hex: 0x897456)],
        [Color(hex: 0xA195A7), Color(hex: 0x75697F)],
        [Color(hex: 0xBA9398), Color(hex: 0x8E6A75)],
        [Color(hex: 0x8BA5A3), Color(hex: 0x5A7D7C)],
        [Color(hex: 0xACA292), Color(hex: 0x7D7467)],
    ]

    static func avatarColors(_ index: Int) -> [Color] {
        let remainder = index % avatarGradients.count
        return avatarGradients[remainder >= 0 ? remainder : remainder + avatarGradients.count]
    }

    static func avatarGradient(_ index: Int) -> LinearGradient {
        LinearGradient(colors: avatarColors(index), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func dossierGradient(_ index: Int) -> LinearGradient {
        let colors = avatarColors(index)
        return LinearGradient(
            colors: [midnight, midnight.mix(with: colors[1], by: 0.35)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 255) / 255,
                  green: CGFloat((rgb >> 8) & 255) / 255,
                  blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}

private extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(rgb: hex)) }
}
