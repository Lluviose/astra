import Foundation

/// 从记录现场算出来的战绩统计。不落盘，数据一变就重算。
///
/// 既可以喂全部记录（战绩统计页），也可以只喂某个人的记录（档案页的「和她」小结）。
struct EncounterInsights: Hashable, Sendable {

    struct Count<Item: Hashable & Sendable>: Hashable, Sendable, Identifiable {
        let item: Item
        let count: Int

        var id: Item { item }
    }

    struct MonthPoint: Hashable, Sendable, Identifiable {
        let monthStart: Date
        let label: String
        let hookups: Int
        let misses: Int

        var id: Date { monthStart }
        var total: Int { hookups + misses }
    }

    /// 一天四段，按上床发生的钟点归类。
    enum DayPart: String, CaseIterable, Hashable, Sendable, Identifiable {
        case morning
        case daytime
        case evening
        case lateNight

        var id: String { rawValue }

        var label: String {
            switch self {
            case .morning: "清晨"
            case .daytime: "白天"
            case .evening: "晚上"
            case .lateNight: "深夜"
            }
        }

        var hoursLabel: String {
            switch self {
            case .morning: "5–10 点"
            case .daytime: "10–18 点"
            case .evening: "18–22 点"
            case .lateNight: "22–5 点"
            }
        }

        var symbolName: String {
            switch self {
            case .morning: "sunrise.fill"
            case .daytime: "sun.max.fill"
            case .evening: "sunset.fill"
            case .lateNight: "moon.stars.fill"
            }
        }

        static func of(hour: Int) -> DayPart {
            switch hour {
            case 5..<10: .morning
            case 10..<18: .daytime
            case 18..<22: .evening
            default: .lateNight
            }
        }
    }

    // MARK: 结果

    var hookupCount = 0
    var missedCount = 0
    var recordCount: Int { hookupCount + missedCount }

    /// 上床 ÷ 全部结果；没有结果时为 nil。
    var hookupRate: Double? {
        guard recordCount > 0 else { return nil }
        return Double(hookupCount) / Double(recordCount)
    }

    /// 真正上过床的人数。
    var companionCount = 0
    /// 同一个人上床 3 次及以上，和首页「回头客」口径一致。
    var repeatCompanionCount = 0
    /// 上过床的地点数。
    var locationCount = 0
    var photoCount = 0

    // MARK: 花费

    var totalSpend: Double = 0
    var spendRecordedCount = 0
    var averageSpend: Double? {
        guard spendRecordedCount > 0 else { return nil }
        return totalSpend / Double(spendRecordedCount)
    }

    // MARK: 套

    /// 只统计上床记录；`notRecorded` 也在里面，方便画出「没记」那一截。
    var protectionCounts: [ProtectionStatus: Int] = [:]

    var protectionRecordedCount: Int {
        protectionCounts.filter { $0.key.isRecorded && $0.key != .notApplicable }.values.reduce(0, +)
    }

    /// 全程戴套 ÷ 记了套的次数。
    var protectedRate: Double? {
        guard protectionRecordedCount > 0 else { return nil }
        return Double(protectionCounts[.protected] ?? 0) / Double(protectionRecordedCount)
    }

    /// 中途摘了 + 无套。
    var barrierGapCount: Int {
        (protectionCounts[.partial] ?? 0) + (protectionCounts[.noProtection] ?? 0)
    }

    // MARK: 玩法

    var topActivities: [Count<IntimacyActivity>] = []
    var topClimaxDetails: [Count<ClimaxDetail>] = []

    // MARK: 时间

    /// 固定四段，顺序不变，便于并排画柱子。
    var dayParts: [Count<DayPart>] = DayPart.allCases.map { Count(item: $0, count: 0) }
    /// 七天，按当前日历的一周起始日排序；`item` 是 `Calendar.weekday`（1 = 周日）。
    var weekdays: [Count<Int>] = []
    var months: [MonthPoint] = []

    var busiestMonth: MonthPoint? {
        months.filter { $0.hookups > 0 }.max { lhs, rhs in
            if lhs.hookups != rhs.hookups { return lhs.hookups < rhs.hookups }
            return lhs.monthStart < rhs.monthStart
        }
    }

    var favoriteDayPart: DayPart? {
        dayParts.filter { $0.count > 0 }.max { $0.count < $1.count }?.item
    }

    var daysSinceLastHookup: Int?
    var longestGapDays: Int?
    var averageGapDays: Double?

    // MARK: 感受与下一步

    var averagePhysical: Double?
    var averageEmotional: Double?
    var meetAgainCounts: [MeetAgainIntent: Int] = [:]

    var wantAgainRate: Double? {
        let decided = MeetAgainIntent.allCases
            .filter { $0 != .notRecorded }
            .reduce(0) { $0 + (meetAgainCounts[$1] ?? 0) }
        guard decided > 0 else { return nil }
        return Double(meetAgainCounts[.yes] ?? 0) / Double(decided)
    }

    // MARK: 排行

    /// 按上床次数排的人，最多 5 个。
    var topCompanions: [Count<UUID>] = []
    /// 按上床次数排的地点 ID，最多 5 个。
    var topLocations: [Count<String>] = []

    var isEmpty: Bool { recordCount == 0 }

    // MARK: - 计算

    static func compute(
        encounters: [Encounter],
        companions: [Companion],
        monthCount: Int = 12,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> EncounterInsights {
        var result = EncounterInsights()
        let companionsByID = companions.reduce(into: [UUID: Companion]()) { $0[$1.id] = $1 }
        let hookups = encounters.filter(\.kind.isIntimate).sorted { $0.date < $1.date }

        result.hookupCount = hookups.count
        result.missedCount = encounters.filter(\.kind.isMissed).count
        result.photoCount = encounters.reduce(0) { $0 + $1.photoIDs.count }

        var perCompanion: [UUID: Int] = [:]
        var perLocation: [String: Int] = [:]
        var activityCounts: [IntimacyActivity: Int] = [:]
        var climaxCounts: [ClimaxDetail: Int] = [:]
        var dayPartCounts: [DayPart: Int] = [:]
        var weekdayCounts: [Int: Int] = [:]
        var physicalTotal = 0
        var physicalCount = 0
        var emotionalTotal = 0
        var emotionalCount = 0

        for encounter in hookups {
            perCompanion[encounter.companionID, default: 0] += 1
            if let locationID = encounter.cityID ?? companionsByID[encounter.companionID]?.cityID {
                perLocation[locationID, default: 0] += 1
            }
            if let cost = encounter.cost, cost > 0 {
                result.totalSpend += cost
                result.spendRecordedCount += 1
            }
            result.protectionCounts[encounter.protectionStatus, default: 0] += 1
            for activity in encounter.activities { activityCounts[activity, default: 0] += 1 }
            for detail in encounter.climaxDetails { climaxCounts[detail, default: 0] += 1 }

            let hour = calendar.component(.hour, from: encounter.date)
            dayPartCounts[DayPart.of(hour: hour), default: 0] += 1
            weekdayCounts[calendar.component(.weekday, from: encounter.date), default: 0] += 1

            if encounter.physicalRating > 0 {
                physicalTotal += encounter.physicalRating
                physicalCount += 1
            }
            if encounter.emotionalRating > 0 {
                emotionalTotal += encounter.emotionalRating
                emotionalCount += 1
            }
        }

        for encounter in encounters where encounter.meetAgainIntent != .notRecorded {
            result.meetAgainCounts[encounter.meetAgainIntent, default: 0] += 1
        }

        result.companionCount = perCompanion.count
        result.repeatCompanionCount = perCompanion.values.filter { $0 >= 3 }.count
        result.locationCount = perLocation.count

        result.topActivities = IntimacyActivity.allCases
            .compactMap { activity in activityCounts[activity].map { Count(item: activity, count: $0) } }
            .sorted { $0.count > $1.count }
            .prefix(8)
            .map { $0 }
        result.topClimaxDetails = ClimaxDetail.allCases
            .compactMap { detail in climaxCounts[detail].map { Count(item: detail, count: $0) } }
            .sorted { $0.count > $1.count }
            .prefix(6)
            .map { $0 }

        result.dayParts = DayPart.allCases.map { Count(item: $0, count: dayPartCounts[$0] ?? 0) }
        result.weekdays = orderedWeekdays(calendar: calendar).map { Count(item: $0, count: weekdayCounts[$0] ?? 0) }
        result.months = monthSeries(encounters: encounters, monthCount: monthCount, now: now, calendar: calendar)

        if physicalCount > 0 { result.averagePhysical = Double(physicalTotal) / Double(physicalCount) }
        if emotionalCount > 0 { result.averageEmotional = Double(emotionalTotal) / Double(emotionalCount) }

        if let last = hookups.last {
            let from = calendar.startOfDay(for: last.date)
            let to = calendar.startOfDay(for: now)
            result.daysSinceLastHookup = max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
        }
        if hookups.count >= 2 {
            var gaps: [Int] = []
            for index in 1..<hookups.count {
                let from = calendar.startOfDay(for: hookups[index - 1].date)
                let to = calendar.startOfDay(for: hookups[index].date)
                gaps.append(max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0))
            }
            result.longestGapDays = gaps.max()
            result.averageGapDays = Double(gaps.reduce(0, +)) / Double(gaps.count)
        }

        result.topCompanions = perCompanion
            .map { Count(item: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                let left = companionsByID[lhs.item]?.displayName ?? ""
                let right = companionsByID[rhs.item]?.displayName ?? ""
                return left.localizedStandardCompare(right) == .orderedAscending
            }
            .prefix(5)
            .map { $0 }
        result.topLocations = perLocation
            .map { Count(item: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.item < rhs.item
            }
            .prefix(5)
            .map { $0 }

        return result
    }

    /// 从本月往前数 `monthCount` 个月，最早的排在最前。
    static func monthSeries(
        encounters: [Encounter],
        monthCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MonthPoint] {
        guard monthCount > 0,
              let currentMonth = calendar.dateInterval(of: .month, for: now)?.start
        else { return [] }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        return stride(from: -(monthCount - 1), through: 0, by: 1).compactMap { offset in
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: currentMonth),
                  let interval = calendar.dateInterval(of: .month, for: monthStart)
            else { return nil }
            var hookups = 0
            var misses = 0
            for encounter in encounters where encounter.date >= interval.start && encounter.date < interval.end {
                if encounter.kind.isIntimate { hookups += 1 } else if encounter.kind.isMissed { misses += 1 }
            }
            return MonthPoint(
                monthStart: monthStart,
                label: formatter.string(from: monthStart),
                hookups: hookups,
                misses: misses
            )
        }
    }

    /// 周几的短标签，如「周一」。
    static func weekdayLabel(_ weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "\(weekday)" }
        return symbols[index]
    }

    private static func orderedWeekdays(calendar: Calendar) -> [Int] {
        let first = max(1, min(calendar.firstWeekday, 7))
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }
}
