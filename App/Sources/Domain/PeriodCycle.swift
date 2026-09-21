import Foundation
import SwiftUI

// MARK: - 经期记录

enum PeriodFlow: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case spotting
    case light
    case medium
    case heavy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spotting: "点滴"
        case .light: "量少"
        case .medium: "中等"
        case .heavy: "量多"
        }
    }

    var symbolName: String {
        switch self {
        case .spotting: "drop"
        case .light: "drop"
        case .medium: "drop.fill"
        case .heavy: "drop.triangle.fill"
        }
    }

    var rank: Int {
        switch self {
        case .spotting: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }

    /// 单独的点滴出血默认不当作新周期起点。
    var countsAsPeriod: Bool { self != .spotting }
}

enum PeriodSymptom: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case cramps
    case headache
    case fatigue
    case moodSwings
    case bloating
    case breastTenderness
    case acne
    case backache
    case nausea
    case insomnia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cramps: "痛经"
        case .headache: "头痛"
        case .fatigue: "乏力"
        case .moodSwings: "情绪波动"
        case .bloating: "腹胀"
        case .breastTenderness: "乳房胀"
        case .acne: "长痘"
        case .backache: "腰痛"
        case .nausea: "恶心"
        case .insomnia: "失眠"
        }
    }
}

/// 一次记下的出血。日期按日历日，不含钟点。
struct PeriodRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var companionID: UUID
    var startDate: Date
    var endDate: Date?
    var flow: PeriodFlow
    var symptoms: Set<PeriodSymptom>
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companionID: UUID,
        startDate: Date = Date(),
        endDate: Date? = nil,
        flow: PeriodFlow = .medium,
        symptoms: Set<PeriodSymptom> = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.companionID = companionID
        self.startDate = startDate
        self.endDate = endDate
        self.flow = flow
        self.symptoms = symptoms
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        normalize(calendar: .current)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        companionID = try c.decodeIfPresent(UUID.self, forKey: .companionID) ?? UUID()
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        flow = try c.decodeIfPresent(PeriodFlow.self, forKey: .flow) ?? .medium
        symptoms = try c.decodeIfPresent(Set<PeriodSymptom>.self, forKey: .symptoms) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        normalize(calendar: .current)
    }

    mutating func normalize(calendar: Calendar) {
        startDate = calendar.startOfDay(for: startDate)
        if let endDate {
            let end = calendar.startOfDay(for: endDate)
            if end < startDate {
                self.endDate = startDate
            } else {
                let days = calendar.dateComponents([.day], from: startDate, to: end).day ?? 0
                if days > CycleEngine.maxPeriodDays {
                    self.endDate = calendar.date(byAdding: .day, value: CycleEngine.maxPeriodDays, to: startDate)
                } else {
                    self.endDate = end
                }
            }
        }
    }

    func inclusiveEnd(asOf: Date = Date(), calendar: Calendar = .current) -> Date {
        if let endDate { return calendar.startOfDay(for: endDate) }
        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: asOf)
        let cap = calendar.date(byAdding: .day, value: CycleEngine.maxPeriodDays, to: start) ?? start
        return max(start, min(today, cap))
    }

    func durationDays(asOf: Date = Date(), calendar: Calendar = .current) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: inclusiveEnd(asOf: asOf, calendar: calendar)).day ?? 0) + 1
    }

    func contains(_ date: Date, asOf: Date = Date(), calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        return day >= start && day <= inclusiveEnd(asOf: asOf, calendar: calendar)
    }
}

// MARK: - 预测结果

enum CycleConfidence: String, Sendable {
    case none
    case low
    case medium
    case high
    case uncertain

    var label: String {
        switch self {
        case .none: "还没把握"
        case .low: "把握较低"
        case .medium: "把握中等"
        case .high: "把握较高"
        case .uncertain: "周期不稳"
        }
    }
}

enum CyclePhase: String, Sendable {
    case unknown
    case bleeding
    case predictedBleeding
    case follicular
    case fertile
    case ovulation
    case luteal
    case late

    var label: String {
        switch self {
        case .unknown: "未开始记"
        case .bleeding: "经期中"
        case .predictedBleeding: "预计经期"
        case .follicular: "卵泡期"
        case .fertile: "易孕窗口"
        case .ovulation: "排卵日"
        case .luteal: "黄体期"
        case .late: "可能推迟"
        }
    }

    var tint: Color {
        switch self {
        case .unknown: .secondary
        case .bleeding, .predictedBleeding: Palette.coral
        case .follicular: Palette.accent
        case .fertile, .ovulation: Palette.iris
        case .luteal: Palette.safe
        case .late: Palette.warning
        }
    }

    var symbolName: String {
        switch self {
        case .unknown: "calendar.badge.plus"
        case .bleeding: "drop.fill"
        case .predictedBleeding: "drop"
        case .follicular: "leaf"
        case .fertile: "heart.circle"
        case .ovulation: "sparkle"
        case .luteal: "moon.fill"
        case .late: "clock.badge.exclamationmark"
        }
    }
}

struct BleedEpisode: Equatable, Sendable {
    var start: Date
    var end: Date
    var isPeriod: Bool
    var flow: PeriodFlow
    var recordIDs: [UUID]

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: start) && day <= calendar.startOfDay(for: end)
    }

    func durationDays(calendar: Calendar) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1
    }
}

struct CycleForecast: Equatable, Sendable {
    var episodes: [BleedEpisode]
    var cycleDays: Int
    var periodDays: Int
    var lutealDays: Int
    var windowRadius: Int
    var confidence: CycleConfidence
    var irregularity: Double
    var sampleCount: Int
    var outlierCount: Int
    var regimeShifted: Bool
    var lastPeriod: BleedEpisode?
    var nextStart: Date?
    var ovulation: Date?
    var fertileStart: Date?
    var fertileEnd: Date?

    var fertileRange: ClosedRange<Date>? {
        guard let fertileStart, let fertileEnd, fertileStart <= fertileEnd else { return nil }
        return fertileStart...fertileEnd
    }

    var nextStartWindow: ClosedRange<Date>? {
        guard let nextStart else { return nil }
        let cal = Calendar.current
        let lo = cal.date(byAdding: .day, value: -windowRadius, to: nextStart) ?? nextStart
        let hi = cal.date(byAdding: .day, value: windowRadius, to: nextStart) ?? nextStart
        return lo...hi
    }
}

struct PeriodSnapshot: Equatable, Sendable {
    var isTracking: Bool
    var phase: CyclePhase
    var headline: String
    var detail: String
    var forecast: CycleForecast
    var dayOfPeriod: Int?
    var lateByDays: Int?
    var openRecord: PeriodRecord?
    var currentRecord: PeriodRecord?
    var loggedCount: Int
    var daysUntilNext: Int?

    var needsHomeAttention: Bool {
        guard isTracking else { return false }
        switch phase {
        case .bleeding, .predictedBleeding, .late, .ovulation, .fertile: return true
        default:
            if let daysUntilNext { return (0...7).contains(daysUntilNext) }
            return false
        }
    }
}

// MARK: - 周期引擎

/// 适配不规则、推迟、点滴、周期迁移和数据很少的情况。
///
/// 黄体期相对稳定（约 12–16 天），变异主要落在卵泡期，所以排卵日从
/// **下次经期往回减黄体期**，而不是从上次经期往后加。周期长度用带近因
/// 权重的稳健中位数，并用 MAD 丢掉极端空窗（漏记、怀孕后、长期停经）。
/// 最近几轮若整体换档（例如停药后变长），会切到新的稳态，而不是被旧数据拉回去。
enum CycleEngine {

    static let minCycleDays = 15
    static let maxCycleDays = 60
    static let defaultCycleDays = 28
    static let minPeriodDays = 1
    static let maxPeriodDays = 12
    static let defaultPeriodDays = 5
    static let mergeGapDays = 2
    static let typicalCycleRange = 21...40

    static func forecast(
        records: [PeriodRecord],
        typicalCycleDays: Int? = nil,
        typicalPeriodDays: Int? = nil,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> CycleForecast {
        let today = calendar.startOfDay(for: asOf)
        let episodes = episodes(from: records, asOf: today, calendar: calendar)
        let periods = episodes.filter(\.isPeriod)
        let lastPeriod = periods.max { $0.start < $1.start }

        let lengths = cycleLengths(periods: periods, calendar: calendar)
        let cycle = estimateCycle(
            lengths: lengths,
            prior: clampCycle(typicalCycleDays) ?? defaultCycleDays
        )
        let durations = periods.map { $0.durationDays(calendar: calendar) }
        let periodDays = estimateDuration(
            values: durations,
            prior: clampPeriod(typicalPeriodDays) ?? defaultPeriodDays
        )
        let luteal = lutealDays(forCycle: cycle.days)

        var nextStart: Date?
        var ovulation: Date?
        var fertileStart: Date?
        var fertileEnd: Date?
        if let last = lastPeriod {
            nextStart = calendar.date(byAdding: .day, value: cycle.days, to: last.start)
            if let nextStart {
                ovulation = calendar.date(byAdding: .day, value: -luteal, to: nextStart)
                if let ovulation {
                    fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulation)
                    fertileEnd = calendar.date(byAdding: .day, value: 1, to: ovulation)
                }
            }
        }

        var window = cycle.windowRadius
        if let nextStart, today > nextStart {
            let late = calendar.dateComponents([.day], from: nextStart, to: today).day ?? 0
            if late > window {
                window = min(10, window + (late / 2))
            }
        }

        return CycleForecast(
            episodes: episodes,
            cycleDays: cycle.days,
            periodDays: periodDays,
            lutealDays: luteal,
            windowRadius: window,
            confidence: cycle.confidence,
            irregularity: cycle.irregularity,
            sampleCount: cycle.sampleCount,
            outlierCount: cycle.outlierCount,
            regimeShifted: cycle.regimeShifted,
            lastPeriod: lastPeriod,
            nextStart: nextStart,
            ovulation: ovulation,
            fertileStart: fertileStart,
            fertileEnd: fertileEnd
        )
    }

    static func snapshot(
        trackingEnabled: Bool,
        records: [PeriodRecord],
        typicalCycleDays: Int? = nil,
        typicalPeriodDays: Int? = nil,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> PeriodSnapshot {
        let today = calendar.startOfDay(for: asOf)
        let forecast = forecast(
            records: records,
            typicalCycleDays: typicalCycleDays,
            typicalPeriodDays: typicalPeriodDays,
            asOf: today,
            calendar: calendar
        )
        let sorted = records.sorted { $0.startDate > $1.startDate }
        let current = sorted.first { $0.contains(today, asOf: today, calendar: calendar) }
        let open = sorted.first { $0.endDate == nil }

        guard trackingEnabled else {
            return PeriodSnapshot(
                isTracking: false,
                phase: .unknown,
                headline: "还没开始记经期",
                detail: "记下每次开始和结束，就能估下次、易孕窗口和推迟。",
                forecast: forecast,
                dayOfPeriod: nil,
                lateByDays: nil,
                openRecord: open,
                currentRecord: current,
                loggedCount: records.count,
                daysUntilNext: nil
            )
        }

        let phase = phase(on: today, records: records, forecast: forecast, calendar: calendar)
        var dayOfPeriod: Int?
        var lateByDays: Int?
        if let last = forecast.lastPeriod, last.contains(today, calendar: calendar) {
            dayOfPeriod = (calendar.dateComponents([.day], from: last.start, to: today).day ?? 0) + 1
        } else if let current {
            dayOfPeriod = (calendar.dateComponents([.day], from: calendar.startOfDay(for: current.startDate), to: today).day ?? 0) + 1
        }
        if phase == .late, let next = forecast.nextStart {
            lateByDays = calendar.dateComponents([.day], from: next, to: today).day
        }
        var daysUntilNext: Int?
        if let next = forecast.nextStart {
            daysUntilNext = calendar.dateComponents([.day], from: today, to: next).day
        }

        let headline = headline(
            phase: phase,
            forecast: forecast,
            dayOfPeriod: dayOfPeriod,
            lateByDays: lateByDays,
            asOf: today,
            calendar: calendar
        )
        let detail = detailText(phase: phase, forecast: forecast, records: records)

        return PeriodSnapshot(
            isTracking: true,
            phase: phase,
            headline: headline,
            detail: detail,
            forecast: forecast,
            dayOfPeriod: dayOfPeriod,
            lateByDays: lateByDays,
            openRecord: open,
            currentRecord: current,
            loggedCount: records.count,
            daysUntilNext: daysUntilNext
        )
    }

    static func phase(
        on date: Date,
        records: [PeriodRecord],
        forecast: CycleForecast,
        calendar: Calendar = .current
    ) -> CyclePhase {
        let day = calendar.startOfDay(for: date)
        if records.contains(where: { $0.contains(day, asOf: day, calendar: calendar) }) {
            return .bleeding
        }
        if forecast.episodes.contains(where: { $0.contains(day, calendar: calendar) }) {
            return .bleeding
        }

        if let next = forecast.nextStart {
            let lastEnd = forecast.lastPeriod?.end ?? .distantPast
            let lateAfter = calendar.date(byAdding: .day, value: forecast.windowRadius, to: next) ?? next
            let predictedEnd = calendar.date(byAdding: .day, value: max(forecast.periodDays - 1, 0), to: next) ?? next
            if day > lastEnd, day > lateAfter {
                return .late
            }
            let windowStart = calendar.date(byAdding: .day, value: -forecast.windowRadius, to: next) ?? next
            if day > lastEnd, day >= windowStart, day <= max(predictedEnd, lateAfter) {
                return .predictedBleeding
            }
        }

        if let ovulation = forecast.ovulation, calendar.isDate(day, inSameDayAs: ovulation) {
            return .ovulation
        }
        if let range = forecast.fertileRange, day >= calendar.startOfDay(for: range.lowerBound), day <= calendar.startOfDay(for: range.upperBound) {
            return .fertile
        }
        if let ovulation = forecast.ovulation, let next = forecast.nextStart, day > ovulation, day < next {
            return .luteal
        }
        if forecast.lastPeriod != nil {
            return .follicular
        }
        return .unknown
    }

    static func dayKind(
        _ date: Date,
        records: [PeriodRecord],
        forecast: CycleForecast,
        calendar: Calendar = .current
    ) -> CyclePhase {
        phase(on: date, records: records, forecast: forecast, calendar: calendar)
    }

    // MARK: 出血合并

    static func episodes(from records: [PeriodRecord], asOf: Date = Date(), calendar: Calendar) -> [BleedEpisode] {
        let sorted = records
            .map { record -> PeriodRecord in
                var copy = record
                copy.normalize(calendar: calendar)
                return copy
            }
            .sorted { $0.startDate < $1.startDate }

        var result: [BleedEpisode] = []
        for record in sorted {
            let start = calendar.startOfDay(for: record.startDate)
            let end = record.inclusiveEnd(asOf: asOf, calendar: calendar)
            if var last = result.last {
                let gap = calendar.dateComponents([.day], from: last.end, to: start).day ?? 999
                if gap <= mergeGapDays {
                    last.end = max(last.end, end)
                    if record.flow.rank > last.flow.rank { last.flow = record.flow }
                    last.recordIDs.append(record.id)
                    last.isPeriod = last.isPeriod || record.flow.countsAsPeriod || last.durationDays(calendar: calendar) >= 3
                    result[result.count - 1] = last
                    continue
                }
            }
            let duration = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            result.append(
                BleedEpisode(
                    start: start,
                    end: end,
                    isPeriod: record.flow.countsAsPeriod || duration >= 3,
                    flow: record.flow,
                    recordIDs: [record.id]
                )
            )
        }
        return result
    }

    // MARK: 周期长度

    private struct CycleEstimate {
        var days: Int
        var windowRadius: Int
        var confidence: CycleConfidence
        var irregularity: Double
        var sampleCount: Int
        var outlierCount: Int
        var regimeShifted: Bool
    }

    private static func cycleLengths(periods: [BleedEpisode], calendar: Calendar) -> [Int] {
        let ordered = periods.sorted { $0.start < $1.start }
        guard ordered.count >= 2 else { return [] }
        var lengths: [Int] = []
        for index in 1..<ordered.count {
            let days = calendar.dateComponents([.day], from: ordered[index - 1].start, to: ordered[index].start).day ?? 0
            if days > 0 { lengths.append(days) }
        }
        return lengths
    }

    private static func estimateCycle(lengths: [Int], prior: Int) -> CycleEstimate {
        let inRange = lengths.filter { (minCycleDays...maxCycleDays).contains($0) }
        let outlierCount = lengths.count - inRange.count

        guard !inRange.isEmpty else {
            return CycleEstimate(
                days: prior,
                windowRadius: 5,
                confidence: lengths.isEmpty ? .none : .uncertain,
                irregularity: lengths.isEmpty ? 0 : 1,
                sampleCount: 0,
                outlierCount: outlierCount,
                regimeShifted: false
            )
        }

        var samples = inRange
        var regimeShifted = false
        if samples.count >= 6 {
            let recentCount = min(4, max(3, samples.count / 2))
            let recent = Array(samples.suffix(recentCount))
            let older = Array(samples.dropLast(recentCount))
            if !older.isEmpty {
                let recentMedian = median(recent.map(Double.init))
                let olderMedian = median(older.map(Double.init))
                let recentMAD = mad(recent, center: recentMedian)
                let olderMAD = mad(older, center: olderMedian)
                if abs(recentMedian - olderMedian) >= 5, recentMAD <= olderMAD + 1.5 {
                    samples = recent
                    regimeShifted = true
                }
            }
        }

        let weights = recencyWeights(count: samples.count)
        let weighted = zip(samples, weights).map { (value: $0.0, weight: $0.1) }
        var center = weightedMedian(weighted)
        let scale = max(mad(samples, center: center), 0.5)
        let cutoff = max(8, 2.5 * 1.4826 * scale)
        let kept = zip(samples, weights).filter { abs(Double($0.0) - center) <= cutoff }
        let dropped = samples.count - kept.count
        if kept.count >= 2 {
            center = weightedMedian(kept.map { (value: $0.0, weight: $0.1) })
        }

        let used = kept.map(\.0)
        let usedCenter = used.isEmpty ? center : weightedMedian(kept.map { (value: $0.0, weight: $0.1) })
        let usedMAD = mad(used.isEmpty ? samples : used, center: usedCenter)
        let sigma = max(1.4826 * usedMAD, 1)
        let mean = used.isEmpty ? usedCenter : used.reduce(0.0) { $0 + Double($1) } / Double(used.count)
        let cv = mean > 0 ? sigma / mean : 1

        var days = Int(usedCenter.rounded())
        if used.count < 3 {
            let blend = (Double(used.count) * usedCenter + Double(3 - used.count) * Double(prior)) / 3
            days = Int(blend.rounded())
        }
        days = min(max(days, used.count < 2 ? typicalCycleRange.lowerBound : minCycleDays), used.count < 2 ? typicalCycleRange.upperBound : 50)

        var window = Int(ceil(sigma * 1.15))
        window = min(max(window, 1), 7)
        if cv > 0.22 { window = max(window, 3) }
        if cv > 0.35 { window = max(window, 5) }

        let confidence: CycleConfidence
        if used.count == 0 {
            confidence = .none
        } else if cv > 0.28 {
            confidence = .uncertain
        } else if used.count >= 4, cv < 0.12 {
            confidence = .high
        } else if used.count >= 2, cv < 0.22 {
            confidence = .medium
        } else {
            confidence = .low
        }

        return CycleEstimate(
            days: days,
            windowRadius: window,
            confidence: confidence,
            irregularity: min(1, cv / 0.4),
            sampleCount: used.count,
            outlierCount: outlierCount + dropped,
            regimeShifted: regimeShifted
        )
    }

    private static func estimateDuration(values: [Int], prior: Int) -> Int {
        let clamped = values.map { min(max($0, minPeriodDays), maxPeriodDays) }
        guard !clamped.isEmpty else { return prior }
        let weights = recencyWeights(count: clamped.count)
        let center = weightedMedian(zip(clamped, weights).map { (value: $0.0, weight: $0.1) })
        return min(max(Int(center.rounded()), 2), 8)
    }

    static func lutealDays(forCycle cycle: Int) -> Int {
        switch cycle {
        case ..<24: return 12
        case 24...26: return 13
        case 27...32: return 14
        case 33...38: return 15
        default: return 16
        }
    }

    static func clampCycle(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return min(max(value, minCycleDays), maxCycleDays)
    }

    static func clampPeriod(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return min(max(value, minPeriodDays), maxPeriodDays)
    }

    static func clampLeadDays(_ value: Int) -> Int {
        min(max(value, 1), 3)
    }

    // MARK: 文案

    private static func headline(
        phase: CyclePhase,
        forecast: CycleForecast,
        dayOfPeriod: Int?,
        lateByDays: Int?,
        asOf: Date,
        calendar: Calendar
    ) -> String {
        switch phase {
        case .unknown:
            return forecast.sampleCount == 0 ? "记下一次经期，就能开始估下次" : "周期还在摸索"
        case .bleeding:
            if let dayOfPeriod { return "经期中 · 第 \(dayOfPeriod) 天" }
            return "经期中"
        case .predictedBleeding:
            if let next = forecast.nextStart {
                if calendar.isDate(asOf, inSameDayAs: next) {
                    return "今天大概会来 · 前后 \(forecast.windowRadius) 天"
                }
                return "预计 \(DateFormatter.dayShort.string(from: next)) 开始 · 前后 \(forecast.windowRadius) 天"
            }
            return "预计经期"
        case .follicular:
            if let next = forecast.nextStart {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: asOf), to: next).day ?? 0
                if days > 1 { return "下次大约 \(days) 天后 · \(DateFormatter.dayShort.string(from: next))" }
                if days == 1 { return "明天大概会来" }
                return "下次大约 \(DateFormatter.dayShort.string(from: next))"
            }
            return "卵泡期"
        case .fertile:
            return "易孕窗口"
        case .ovulation:
            return "今天可能排卵"
        case .luteal:
            if let next = forecast.nextStart {
                return "黄体期 · 下次大约 \(DateFormatter.dayShort.string(from: next))"
            }
            return "黄体期"
        case .late:
            if let lateByDays, lateByDays > 0 { return "已经晚了 \(lateByDays) 天" }
            return "可能推迟了"
        }
    }

    private static func detailText(phase: CyclePhase, forecast: CycleForecast, records: [PeriodRecord]) -> String {
        if records.isEmpty {
            return "有她说的大概周期也可以先填着，真正记下一次开始日期后才会给出日期。"
        }
        var parts: [String] = []
        parts.append("周期约 \(forecast.cycleDays) 天 ± \(forecast.windowRadius)")
        parts.append("经期约 \(forecast.periodDays) 天")
        parts.append(forecast.confidence.label)
        if forecast.regimeShifted {
            parts.append("最近几轮换过节奏，已按新的来估")
        } else if forecast.irregularity >= 0.55 {
            parts.append("波动比较大，窗口会放宽")
        }
        if forecast.outlierCount > 0 {
            parts.append("有 \(forecast.outlierCount) 段过长空窗没计入均值")
        }
        if phase == .late {
            parts.append("推迟不一定是怀孕，先记下实际来的那天")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: 统计

    static func recencyWeights(count: Int, halfLife: Double = 3) -> [Double] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let age = Double(count - 1 - index)
            return pow(0.5, age / halfLife)
        }
    }

    static func weightedMedian(_ items: [(value: Int, weight: Double)]) -> Double {
        let filtered = items.filter { $0.weight > 0 }
        guard !filtered.isEmpty else { return 0 }
        let sorted = filtered.sorted { $0.value < $1.value }
        let total = sorted.reduce(0.0) { $0 + $1.weight }
        var cumulative = 0.0
        for item in sorted {
            cumulative += item.weight
            if cumulative >= total / 2 { return Double(item.value) }
        }
        return Double(sorted.last?.value ?? 0)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    static func mad(_ values: [Int], center: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        return median(values.map { abs(Double($0) - center) })
    }
}
