import Foundation
import SwiftUI

// MARK: - 设置项

enum MapSkin: String, Codable, CaseIterable, Sendable, Identifiable {
    case muted
    case standard
    case satellite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .muted: "素雅"
        case .standard: "标准"
        case .satellite: "卫星"
        }
    }

    var symbolName: String {
        switch self {
        case .muted: "map"
        case .standard: "map.fill"
        case .satellite: "globe.asia.australia.fill"
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppSettings: Codable, Hashable, Sendable {
    // 隐私
    /// 面容 / 触控 ID 解锁
    var appLockEnabled: Bool = false
    /// 切到后台时给多任务卡片盖一层毛玻璃，防止被瞥见
    var privacyScreenEnabled: Bool = true
    /// 对象页默认打码，需要主动点眼睛才显示代号
    var maskNamesByDefault: Bool = true

    // 触感
    var hapticsEnabled: Bool = true
    /// 0.35 ~ 1.0
    var hapticIntensity: Double = 1.0

    // 外观
    var appearance: AppearancePreference = .system
    var mapSkin: MapSkin = .muted
    /// 城市气泡下的光晕
    var showHeatGlow: Bool = true

    // 对象页
    var rosterSort: RosterSort = .lastContact
    var rosterGrouping: RosterGrouping = .stage

    static let `default` = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appLockEnabled = try c.decodeIfPresent(Bool.self, forKey: .appLockEnabled) ?? false
        privacyScreenEnabled = try c.decodeIfPresent(Bool.self, forKey: .privacyScreenEnabled) ?? true
        maskNamesByDefault = try c.decodeIfPresent(Bool.self, forKey: .maskNamesByDefault) ?? true
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        hapticIntensity = try c.decodeIfPresent(Double.self, forKey: .hapticIntensity) ?? 1.0
        appearance = try c.decodeIfPresent(AppearancePreference.self, forKey: .appearance) ?? .system
        mapSkin = try c.decodeIfPresent(MapSkin.self, forKey: .mapSkin) ?? .muted
        showHeatGlow = try c.decodeIfPresent(Bool.self, forKey: .showHeatGlow) ?? true
        rosterSort = try c.decodeIfPresent(RosterSort.self, forKey: .rosterSort) ?? .lastContact
        rosterGrouping = try c.decodeIfPresent(RosterGrouping.self, forKey: .rosterGrouping) ?? .stage
    }
}

// MARK: - 持久化

/// 极简本地存储。对象与亲密记录的主存储在 App 沙盒，并允许随系统设备备份恢复。
struct LocalStore {

    enum Key: String {
        case companions = "astra.companions"
        case encounters = "astra.encounters"
        case settings = "astra.settings"
        case filter = "astra.filter"
        case seenAchievements = "astra.seenAchievements"
    }

    static let shared = LocalStore()

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load<T: Decodable>(_ type: T.Type, for key: Key, default fallback: T) -> T {
        guard let data = defaults.data(forKey: key.rawValue) else { return fallback }
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    func save<T: Encodable>(_ value: T, for key: Key) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    func removeAll() {
        for key in [Key.companions, .encounters, .settings, .filter, .seenAchievements] {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}
