import SwiftUI
import UIKit
import XCTest
@testable import Astra

final class DesignAccessibilityTests: XCTestCase {
    @MainActor
    func testReadingAndActionColorsHaveNormalTextContrastInBothAppearances() {
        let foregrounds: [(String, Color)] = [
            ("正文", Palette.ink), ("次要文字", Palette.secondaryInk),
            ("强调", Palette.accent), ("结果", Palette.coral),
            ("保护状态", Palette.safe), ("提醒", Palette.warning),
        ]
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: appearance)
            for background in [Palette.background, Palette.surface] {
                for (name, foreground) in foregrounds {
                    let first = luminance(UIColor(foreground).resolvedColor(with: traits))
                    let second = luminance(UIColor(background).resolvedColor(with: traits))
                    let contrast = (max(first, second) + 0.05) / (min(first, second) + 0.05)
                    XCTAssertGreaterThanOrEqual(contrast, 4.5, "\(name), appearance \(appearance.rawValue)")
                }
            }
        }
    }

    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
