import Foundation

/// 对象页的筛选条件。空集合表示「不限」。
struct RosterFilter: Codable, Hashable, Sendable {
    var stages: Set<RelationStage> = []
    var cityIDs: Set<String> = []
    var tags: Set<String> = []
    /// 0 表示不限
    var minRating: Int = 0
    var includeArchived: Bool = false
    /// 只看已经到达联系周期的对象
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

    /// - Parameter isOverdue: 是否已超过该对象的联系周期
    func matches(_ companion: Companion, isOverdue: Bool) -> Bool {
        if !includeArchived, companion.isArchived { return false }
        if !stages.isEmpty, !stages.contains(companion.stage) { return false }
        if !cityIDs.isEmpty, !cityIDs.contains(companion.cityID) { return false }
        if minRating > 0, companion.overallScore < minRating * 20 { return false }
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
    case hookups

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastContact: "最近互动"
        case .rating: "综合评分"
        case .stage: "相处状态"
        case .name: "代号"
        case .city: "城市"
        case .added: "添加时间"
        case .hookups: "上床次数"
        }
    }

    var symbolName: String {
        switch self {
        case .lastContact: "clock.arrow.circlepath"
        case .rating: "star.fill"
        case .stage: "circle.grid.2x2.fill"
        case .name: "textformat.abc"
        case .city: "map"
        case .added: "calendar.badge.plus"
        case .hookups: "flame.fill"
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
        case .stage: "按状态"
        case .city: "按城市"
        }
    }
}

// MARK: - 亲密记录统计

struct IntimacyStats: Hashable, Sendable {
    var activeCount: Int = 0
    var totalIntimacyCount: Int = 0
    var missedCount: Int = 0
    var intimaciesThisMonth: Int = 0
    var missedThisMonth: Int = 0
    var safetyRecordedThisMonth: Int = 0
    var unprotectedThisMonth: Int = 0
    var pendingFollowUpCount: Int = 0
    var photoCount: Int = 0
    var cityCount: Int = 0
    var averageExperience: Double?
    var girlsThisMonth: Int = 0
    var photosThisMonth: Int = 0
    var repeatGirlCount: Int = 0
    var topCompanionID: UUID?
    var topCityName: String?
}
