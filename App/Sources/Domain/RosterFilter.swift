import Foundation

/// 名单页的筛选条件。空集合表示「不限」。
struct RosterFilter: Codable, Hashable, Sendable {
    var stages: Set<RelationStage> = []
    var cityIDs: Set<String> = []
    var tags: Set<String> = []
    /// 0 表示不限
    var minRating: Int = 0
    var includeArchived: Bool = false
    /// 只看「该联系了」的人
    var needsContactOnly: Bool = false

    static let `default` = RosterFilter()

    var isDefault: Bool { self == .default }

    var activeConditionCount: Int {
        var count = 0
        if !stages.isEmpty { count += 1 }
        if !cityIDs.isEmpty { count += 1 }
        if !tags.isEmpty { count += 1 }
        if minRating > 0 { count += 1 }
        if includeArchived { count += 1 }
        if needsContactOnly { count += 1 }
        return count
    }

    /// - Parameter isOverdue: 是否已超过该人的提醒间隔
    func matches(_ companion: Companion, isOverdue: Bool) -> Bool {
        if !includeArchived, companion.isArchived { return false }
        if !stages.isEmpty, !stages.contains(companion.stage) { return false }
        if !cityIDs.isEmpty, !cityIDs.contains(companion.cityID) { return false }
        if minRating > 0, companion.rating < minRating { return false }
        if !tags.isEmpty, tags.isDisjoint(with: companion.tags) { return false }
        if needsContactOnly, !isOverdue { return false }
        return true
    }

    mutating func toggle(stage: RelationStage) {
        if stages.contains(stage) { stages.remove(stage) } else { stages.insert(stage) }
    }

    mutating func toggle(tag: String) {
        if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
    }

    mutating func toggle(cityID: String) {
        if cityIDs.contains(cityID) { cityIDs.remove(cityID) } else { cityIDs.insert(cityID) }
    }
}

enum RosterSort: String, CaseIterable, Codable, Sendable, Identifiable {
    case lastContact
    case rating
    case stage
    case name
    case city
    case added

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastContact: "最近联系"
        case .rating: "心动指数"
        case .stage: "关系阶段"
        case .name: "名字"
        case .city: "城市"
        case .added: "添加时间"
        }
    }

    var symbolName: String {
        switch self {
        case .lastContact: "clock.arrow.circlepath"
        case .rating: "star.fill"
        case .stage: "heart.text.square"
        case .name: "textformat.abc"
        case .city: "map"
        case .added: "calendar.badge.plus"
        }
    }
}

enum RosterGrouping: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case stage
    case city

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "不分组"
        case .stage: "按阶段"
        case .city: "按城市"
        }
    }
}

// MARK: - 统计

struct RosterStats: Hashable, Sendable {
    var activeCount: Int = 0
    var archivedCount: Int = 0
    var cityCount: Int = 0
    var stageBreakdown: [RelationStage: Int] = [:]
    var encountersThisMonth: Int = 0
    var meetupsThisMonth: Int = 0
    var spendThisMonth: Double = 0
    var spendAllTime: Double = 0
    var averageMood: Double?
    /// 最久没联系的人
    var longestSilenceName: String?
    var longestSilenceDays: Int?
    var busiestCityName: String?
}
