import Foundation
import SwiftUI

// MARK: - 可定制王者档案

enum RoyalBannerStyle: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case velvet
    case imperial
    case midnight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .velvet: "绯夜"
        case .imperial: "帝金"
        case .midnight: "黑曜"
        }
    }

    var symbolName: String {
        switch self {
        case .velvet: "flame.fill"
        case .imperial: "crown.fill"
        case .midnight: "moon.stars.fill"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .velvet: Palette.velvetGradient
        case .imperial:
            LinearGradient(
                colors: [Palette.midnight, Palette.midnight.mix(with: Palette.gold, by: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnight:
            LinearGradient(
                colors: [Palette.midnight, Color(red: 0.14, green: 0.19, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct RoyalProfile: Codable, Hashable, Sendable {
    /// 0 起算，对应已经到达过的 RoyalRank 档位。
    var selectedTitleIndex: Int?
    var bannerStyle: RoyalBannerStyle
    var capitalLocationID: String?

    static let `default` = RoyalProfile(
        selectedTitleIndex: nil,
        bannerStyle: .velvet,
        capitalLocationID: nil
    )

    init(
        selectedTitleIndex: Int? = nil,
        bannerStyle: RoyalBannerStyle = .velvet,
        capitalLocationID: String? = nil
    ) {
        self.selectedTitleIndex = selectedTitleIndex
        self.bannerStyle = bannerStyle
        self.capitalLocationID = capitalLocationID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selectedTitleIndex = try c.decodeIfPresent(Int.self, forKey: .selectedTitleIndex)
        bannerStyle = try c.decodeIfPresent(RoyalBannerStyle.self, forKey: .bannerStyle) ?? .velvet
        capitalLocationID = try c.decodeIfPresent(String.self, forKey: .capitalLocationID)
    }
}

// MARK: - 传奇与领地

enum CompanionLegendTier: Int, CaseIterable, Hashable, Sendable, Identifiable {
    case none
    case first
    case returner
    case ace
    case legendary

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "未猎获"
        case .first: "初猎"
        case .returner: "回头"
        case .ace: "王牌"
        case .legendary: "传奇"
        }
    }

    var threshold: Int {
        switch self {
        case .none: 0
        case .first: 1
        case .returner: 3
        case .ace: 5
        case .legendary: 10
        }
    }

    var symbolName: String {
        switch self {
        case .none: "lock.fill"
        case .first: "seal.fill"
        case .returner: "arrow.triangle.2.circlepath"
        case .ace: "star.fill"
        case .legendary: "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .none: .secondary
        case .first: Color(red: 0.72, green: 0.43, blue: 0.25)
        case .returner: Color(red: 0.68, green: 0.72, blue: 0.82)
        case .ace: Palette.goldDeep
        case .legendary: Palette.coral
        }
    }

    var next: CompanionLegendTier? {
        CompanionLegendTier(rawValue: rawValue + 1)
    }

    static func resolve(hookupCount: Int) -> CompanionLegendTier {
        allCases.last { hookupCount >= $0.threshold } ?? .none
    }
}

struct CompanionLegend: Identifiable, Hashable, Sendable {
    let companionID: UUID
    let hookupCount: Int
    let privatePhotoCount: Int
    let lastHookupDate: Date

    var id: UUID { companionID }
    var tier: CompanionLegendTier { .resolve(hookupCount: hookupCount) }
    var nextThreshold: Int? { tier.next?.threshold }
    var remainingToNext: Int? { nextThreshold.map { max(0, $0 - hookupCount) } }
}

enum TerritoryTier: Int, CaseIterable, Hashable, Sendable, Identifiable {
    case none
    case conquered
    case outpost
    case stronghold
    case royalCity

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "未占领"
        case .conquered: "初征"
        case .outpost: "据点"
        case .stronghold: "主场"
        case .royalCity: "王城"
        }
    }

    var threshold: Int {
        switch self {
        case .none: 0
        case .conquered: 1
        case .outpost: 3
        case .stronghold: 8
        case .royalCity: 15
        }
    }

    var symbolName: String {
        switch self {
        case .none: "mappin"
        case .conquered: "flag.fill"
        case .outpost: "shield.fill"
        case .stronghold: "building.columns.fill"
        case .royalCity: "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .none: .secondary
        case .conquered: Palette.coral
        case .outpost: Palette.accent
        case .stronghold: Palette.goldDeep
        case .royalCity: Palette.gold
        }
    }

    var next: TerritoryTier? { TerritoryTier(rawValue: rawValue + 1) }

    static func resolve(hookupCount: Int) -> TerritoryTier {
        allCases.last { hookupCount >= $0.threshold } ?? .none
    }
}

struct ConquestTerritory: Identifiable, Hashable, Sendable {
    let locationID: String
    let hookupCount: Int
    let companionCount: Int
    let repeatCompanionCount: Int
    let firstHookupDate: Date
    let lastHookupDate: Date
    let bestMonthCount: Int

    var id: String { locationID }
    var tier: TerritoryTier { .resolve(hookupCount: hookupCount) }
    var remainingToNext: Int? { tier.next.map { max(0, $0.threshold - hookupCount) } }
}

// MARK: - 编年史与个人纪录

enum CampaignScope: String, Hashable, Sendable {
    case month
    case year
}

struct CampaignSummary: Identifiable, Hashable, Sendable {
    let periodStart: Date
    let scope: CampaignScope
    let hookupCount: Int
    let companionCount: Int
    let repeatCompanionCount: Int
    let newConquestCount: Int
    let newTerritoryCount: Int
    let topCompanionID: UUID?
    let topLocationID: String?

    var id: String { "\(scope.rawValue)-\(periodStart.timeIntervalSince1970)" }
}

enum PersonalRecordMetric: String, CaseIterable, Hashable, Sendable, Identifiable {
    case singleDay
    case monthHookups
    case yearHookups
    case monthNewConquests
    case monthNewTerritories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleDay: "单日最多"
        case .monthHookups: "单月最多"
        case .yearHookups: "年度最多"
        case .monthNewConquests: "单月新猎获"
        case .monthNewTerritories: "单月新领地"
        }
    }

    var symbolName: String {
        switch self {
        case .singleDay: "sun.max.fill"
        case .monthHookups: "calendar"
        case .yearHookups: "calendar.badge.checkmark"
        case .monthNewConquests: "person.badge.plus"
        case .monthNewTerritories: "flag.fill"
        }
    }
}

struct PersonalRecord: Identifiable, Hashable, Sendable {
    let metric: PersonalRecordMetric
    let value: Int
    let achievedAt: Date

    var id: String { metric.id }
}

struct RoyalDashboard: Hashable, Sendable {
    let legends: [CompanionLegend]
    let territories: [ConquestTerritory]
    let monthlyCampaigns: [CampaignSummary]
    let yearlyCampaigns: [CampaignSummary]
    let personalRecords: [PersonalRecord]

    var bestMonth: CampaignSummary? {
        monthlyCampaigns.max {
            if $0.hookupCount != $1.hookupCount { return $0.hookupCount < $1.hookupCount }
            return $0.periodStart < $1.periodStart
        }
    }
}

/// 分享层唯一允许接收的数据白名单；刻意不提供人物、地点、日期、媒体或备注字段。
struct AnonymousRoyalSharePayload: Codable, Hashable, Sendable {
    let title: String
    let level: Int
    let companionCount: Int
    let hookupCount: Int
    let repeatCount: Int
    let territoryCount: Int
    let year: Int
    let yearHookups: Int
}

struct RoyalSnapshot: Hashable, Sendable {
    let legendTiers: [UUID: CompanionLegendTier]
    let territoryTiers: [String: TerritoryTier]
    let records: [PersonalRecordMetric: Int]
}

struct RewardEvent: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case personalRecord
        case legendUpgrade
        case territoryUpgrade
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    let symbolName: String
    let tint: RewardTint
}

/// RewardEvent 跨 actor 传递时不携带 SwiftUI Color。
enum RewardTint: Hashable, Sendable {
    case coral
    case accent
    case gold

    var color: Color {
        switch self {
        case .coral: Palette.coral
        case .accent: Palette.accent
        case .gold: Palette.gold
        }
    }
}

// MARK: - 派生引擎

enum RoyalConquestEngine {
    static func build(
        companions: [Companion],
        encounters: [Encounter],
        albumCount: (UUID) -> Int
    ) -> RoyalDashboard {
        let hookups = encounters.filter(\.kind.isIntimate)
        let companionByID = companions.reduce(into: [UUID: Companion]()) { result, companion in
            if let current = result[companion.id], current.updatedAt > companion.updatedAt { return }
            result[companion.id] = companion
        }
        let groupedByCompanion = Dictionary(grouping: hookups, by: \.companionID)
        let legends = groupedByCompanion.compactMap { companionID, records -> CompanionLegend? in
            guard companionByID[companionID] != nil,
                  let last = records.map(\.date).max()
            else { return nil }
            return CompanionLegend(
                companionID: companionID,
                hookupCount: records.count,
                privatePhotoCount: albumCount(companionID),
                lastHookupDate: last
            )
        }
        .sorted {
            if $0.tier.rawValue != $1.tier.rawValue { return $0.tier.rawValue > $1.tier.rawValue }
            if $0.hookupCount != $1.hookupCount { return $0.hookupCount > $1.hookupCount }
            return $0.lastHookupDate > $1.lastHookupDate
        }

        func locationID(for encounter: Encounter) -> String? {
            encounter.cityID ?? companionByID[encounter.companionID]?.cityID
        }

        let locationGroups = Dictionary(grouping: hookups.compactMap { encounter -> (String, Encounter)? in
            locationID(for: encounter).map { ($0, encounter) }
        }, by: { $0.0 })
        let territories = locationGroups.compactMap { locationID, pairs -> ConquestTerritory? in
            let records = pairs.map { $0.1 }
            guard let first = records.map(\.date).min(), let last = records.map(\.date).max() else { return nil }
            let companionCounts = Dictionary(grouping: records, by: \.companionID).mapValues { $0.count }
            let monthlyCounts = Dictionary(grouping: records) { monthStart(for: $0.date) }.mapValues { $0.count }
            return ConquestTerritory(
                locationID: locationID,
                hookupCount: records.count,
                companionCount: companionCounts.count,
                repeatCompanionCount: companionCounts.values.filter { $0 >= 3 }.count,
                firstHookupDate: first,
                lastHookupDate: last,
                bestMonthCount: monthlyCounts.values.max() ?? 0
            )
        }
        .sorted {
            if $0.tier.rawValue != $1.tier.rawValue { return $0.tier.rawValue > $1.tier.rawValue }
            if $0.hookupCount != $1.hookupCount { return $0.hookupCount > $1.hookupCount }
            return $0.lastHookupDate > $1.lastHookupDate
        }

        let firstByCompanion = Dictionary(grouping: hookups, by: \.companionID).compactMapValues { $0.map(\.date).min() }
        let firstByLocation = Dictionary(grouping: hookups.compactMap { encounter -> (String, Date)? in
            locationID(for: encounter).map { ($0, encounter.date) }
        }, by: { $0.0 }).compactMapValues { $0.map { $0.1 }.min() }

        let months = campaignSummaries(
            hookups: hookups,
            scope: .month,
            companionByID: companionByID,
            firstByCompanion: firstByCompanion,
            firstByLocation: firstByLocation
        )
        let years = campaignSummaries(
            hookups: hookups,
            scope: .year,
            companionByID: companionByID,
            firstByCompanion: firstByCompanion,
            firstByLocation: firstByLocation
        )

        var records: [PersonalRecord] = []
        if let day = bestGroupedCount(hookups, start: { Calendar.current.startOfDay(for: $0.date) }) {
            records.append(PersonalRecord(metric: .singleDay, value: day.count, achievedAt: day.date))
        }
        if let month = months.max(by: recordLess) {
            records.append(PersonalRecord(metric: .monthHookups, value: month.hookupCount, achievedAt: month.periodStart))
        }
        if let year = years.max(by: recordLess) {
            records.append(PersonalRecord(metric: .yearHookups, value: year.hookupCount, achievedAt: year.periodStart))
        }
        if let conquest = months.max(by: { $0.newConquestCount < $1.newConquestCount }), conquest.newConquestCount > 0 {
            records.append(PersonalRecord(metric: .monthNewConquests, value: conquest.newConquestCount, achievedAt: conquest.periodStart))
        }
        if let territory = months.max(by: { $0.newTerritoryCount < $1.newTerritoryCount }), territory.newTerritoryCount > 0 {
            records.append(PersonalRecord(metric: .monthNewTerritories, value: territory.newTerritoryCount, achievedAt: territory.periodStart))
        }

        return RoyalDashboard(
            legends: legends,
            territories: territories,
            monthlyCampaigns: months,
            yearlyCampaigns: years,
            personalRecords: records
        )
    }

    static func snapshot(_ dashboard: RoyalDashboard) -> RoyalSnapshot {
        RoyalSnapshot(
            legendTiers: Dictionary(uniqueKeysWithValues: dashboard.legends.map { ($0.companionID, $0.tier) }),
            territoryTiers: Dictionary(uniqueKeysWithValues: dashboard.territories.map { ($0.locationID, $0.tier) }),
            records: Dictionary(uniqueKeysWithValues: dashboard.personalRecords.map { ($0.metric, $0.value) })
        )
    }

    private static func campaignSummaries(
        hookups: [Encounter],
        scope: CampaignScope,
        companionByID: [UUID: Companion],
        firstByCompanion: [UUID: Date],
        firstByLocation: [String: Date]
    ) -> [CampaignSummary] {
        func start(_ date: Date) -> Date {
            switch scope {
            case .month: monthStart(for: date)
            case .year: yearStart(for: date)
            }
        }

        let grouped = Dictionary(grouping: hookups) { start($0.date) }
        return grouped.map { periodStart, items in
            let companionCounts = Dictionary(grouping: items, by: \.companionID).mapValues { $0.count }
            let locations = items.compactMap { $0.cityID ?? companionByID[$0.companionID]?.cityID }
            let locationCounts = Dictionary(grouping: locations, by: { $0 }).mapValues { $0.count }
            let newCompanions = firstByCompanion.values.filter { start($0) == periodStart }.count
            let newLocations = firstByLocation.values.filter { start($0) == periodStart }.count
            return CampaignSummary(
                periodStart: periodStart,
                scope: scope,
                hookupCount: items.count,
                companionCount: companionCounts.count,
                repeatCompanionCount: companionCounts.values.filter { $0 >= 3 }.count,
                newConquestCount: newCompanions,
                newTerritoryCount: newLocations,
                topCompanionID: companionCounts.max { $0.value < $1.value }?.key,
                topLocationID: locationCounts.max { $0.value < $1.value }?.key
            )
        }
        .sorted { $0.periodStart > $1.periodStart }
    }

    private static func monthStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private static func yearStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .year, for: date)?.start ?? date
    }

    private static func bestGroupedCount(
        _ hookups: [Encounter],
        start: (Encounter) -> Date
    ) -> (date: Date, count: Int)? {
        Dictionary(grouping: hookups, by: start)
            .map { (date: $0.key, count: $0.value.count) }
            .max {
                if $0.count != $1.count { return $0.count < $1.count }
                return $0.date < $1.date
            }
    }

    private static func recordLess(_ lhs: CampaignSummary, _ rhs: CampaignSummary) -> Bool {
        if lhs.hookupCount != rhs.hookupCount { return lhs.hookupCount < rhs.hookupCount }
        return lhs.periodStart < rhs.periodStart
    }
}
