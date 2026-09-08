import XCTest
@testable import Astra

final class InsightsTests: XCTestCase {

    func testEmptyInsightsHaveNoRatesAndKeepFixedBuckets() {
        let insights = EncounterInsights.compute(encounters: [], companions: [])
        XCTAssertTrue(insights.isEmpty)
        XCTAssertNil(insights.hookupRate)
        XCTAssertNil(insights.protectedRate)
        XCTAssertNil(insights.wantAgainRate)
        XCTAssertEqual(insights.dayParts.count, 4)
        XCTAssertEqual(insights.weekdays.count, 7)
        XCTAssertEqual(insights.months.count, 12)
        XCTAssertTrue(insights.months.allSatisfy { $0.total == 0 })
    }

    func testCountsRatesSpendAndProtection() {
        let her = Companion(name: "她", cityID: "310000")
        let other = Companion(name: "另一个", cityID: "110000")
        let base = stableMidday()
        let encounters = [
            Encounter(companionID: her.id, date: base, kind: .intimacy, cost: 300, activities: [.doggy, .oralReceiving], climaxDetails: [.creampie], protectionStatus: .noProtection, meetAgainIntent: .yes),
            Encounter(companionID: her.id, date: base.addingTimeInterval(86_400 * 2), kind: .intimacy, cost: 500, activities: [.doggy], protectionStatus: .protected, meetAgainIntent: .yes),
            Encounter(companionID: her.id, date: base.addingTimeInterval(86_400 * 6), kind: .intimacy, activities: [.doggy, .cowgirl], protectionStatus: .partial, meetAgainIntent: .maybe),
            Encounter(companionID: other.id, date: base.addingTimeInterval(86_400 * 3), kind: .missed, cityID: "110000", meetAgainIntent: .no),
        ]

        let insights = EncounterInsights.compute(
            encounters: encounters,
            companions: [her, other],
            now: base.addingTimeInterval(86_400 * 8)
        )

        XCTAssertEqual(insights.hookupCount, 3)
        XCTAssertEqual(insights.missedCount, 1)
        XCTAssertEqual(insights.hookupRate ?? 0, 0.75, accuracy: 0.001)
        XCTAssertEqual(insights.companionCount, 1)
        XCTAssertEqual(insights.repeatCompanionCount, 1)
        XCTAssertEqual(insights.locationCount, 1)

        XCTAssertEqual(insights.totalSpend, 800)
        XCTAssertEqual(insights.spendRecordedCount, 2)
        XCTAssertEqual(insights.averageSpend ?? 0, 400, accuracy: 0.001)

        XCTAssertEqual(insights.protectionRecordedCount, 3)
        XCTAssertEqual(insights.protectedRate ?? 0, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(insights.barrierGapCount, 2)

        XCTAssertEqual(insights.topActivities.first?.item, .doggy)
        XCTAssertEqual(insights.topActivities.first?.count, 3)
        XCTAssertEqual(insights.topClimaxDetails.first?.item, .creampie)

        XCTAssertEqual(insights.topCompanions.first?.item, her.id)
        XCTAssertEqual(insights.topCompanions.first?.count, 3)
        XCTAssertEqual(insights.topLocations.first?.item, "310000")

        XCTAssertEqual(insights.wantAgainRate ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(insights.daysSinceLastHookup, 2)
        XCTAssertEqual(insights.longestGapDays, 4)
        XCTAssertEqual(insights.averageGapDays ?? 0, 3, accuracy: 0.001)
        XCTAssertEqual(insights.favoriteDayPart, .daytime)
    }

    func testRhythmAveragesInitiatorAndMilestones() {
        let her = Companion(name: "她")
        let base = stableMidday()
        let encounters = [
            Encounter(companionID: her.id, date: base, kind: .intimacy, physicalRating: 3,
                      initiator: .me, rounds: 1, durationMinutes: 30),
            Encounter(companionID: her.id, date: base.addingTimeInterval(86_400), kind: .intimacy, physicalRating: 5,
                      initiator: .her, rounds: 3, durationMinutes: 60),
            Encounter(companionID: her.id, date: base.addingTimeInterval(86_400 * 2), kind: .intimacy, physicalRating: 5,
                      initiator: .her),
            Encounter(companionID: her.id, date: base.addingTimeInterval(86_400 * 3), kind: .missed,
                      initiator: .me, rounds: 4, durationMinutes: 90),
        ]
        let insights = EncounterInsights.compute(encounters: encounters, companions: [her], now: base.addingTimeInterval(86_400 * 4))

        XCTAssertEqual(insights.averageDurationMinutes ?? 0, 45, accuracy: 0.001)
        XCTAssertEqual(insights.averageRounds ?? 0, 2, accuracy: 0.001)
        XCTAssertEqual(insights.initiatorCounts[.her], 2)
        XCTAssertEqual(insights.initiatorCounts[.me], 1)
        XCTAssertEqual(insights.dominantInitiator, .her)
        XCTAssertEqual(insights.firstHookupDate, base)
        // 同为 5 分时取更近的一次
        XCTAssertEqual(insights.bestHookupID, encounters[2].id)

        let empty = EncounterInsights.compute(encounters: [], companions: [])
        XCTAssertNil(empty.averageDurationMinutes)
        XCTAssertNil(empty.averageRounds)
        XCTAssertNil(empty.dominantInitiator)
        XCTAssertNil(empty.firstHookupDate)
        XCTAssertNil(empty.bestHookupID)
    }

    func testMissedRecordsNeverLeakIntoIntimateStatistics() {
        let her = Companion(name: "她")
        let missed = Encounter(
            companionID: her.id,
            kind: .missed,
            cost: 200,
            activities: [.doggy],
            protectionStatus: .noProtection
        )
        let insights = EncounterInsights.compute(encounters: [missed], companions: [her])

        XCTAssertEqual(insights.missedCount, 1)
        XCTAssertEqual(insights.hookupCount, 0)
        XCTAssertEqual(insights.totalSpend, 0)
        XCTAssertTrue(insights.topActivities.isEmpty)
        XCTAssertTrue(insights.protectionCounts.isEmpty)
        XCTAssertEqual(insights.companionCount, 0)
    }

    func testDayPartBoundaries() {
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 4), .lateNight)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 5), .morning)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 9), .morning)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 10), .daytime)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 17), .daytime)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 18), .evening)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 21), .evening)
        XCTAssertEqual(EncounterInsights.DayPart.of(hour: 22), .lateNight)
    }

    func testMonthSeriesEndsWithCurrentMonth() {
        let calendar = Calendar.current
        let now = Date()
        let series = EncounterInsights.monthSeries(encounters: [], monthCount: 6, now: now, calendar: calendar)
        XCTAssertEqual(series.count, 6)
        XCTAssertEqual(series.last?.monthStart, calendar.dateInterval(of: .month, for: now)?.start)
        XCTAssertTrue(zip(series, series.dropFirst()).allSatisfy { $0.monthStart < $1.monthStart })
    }

    func testRoyalRankBands() {
        XCTAssertEqual(RoyalRank(unlockedCount: 0, totalCount: 50).title, "猎场开张")
        XCTAssertEqual(RoyalRank(unlockedCount: 0, totalCount: 50).level, 1)
        XCTAssertEqual(RoyalRank(unlockedCount: 9, totalCount: 50).nextThreshold, 10)
        XCTAssertEqual(RoyalRank(unlockedCount: 10, totalCount: 50).title, "初露锋芒")
        XCTAssertEqual(RoyalRank(unlockedCount: 23, totalCount: 50).level, 3)
        XCTAssertEqual(RoyalRank(unlockedCount: 23, totalCount: 50).remainingToNext, 7)
        XCTAssertEqual(RoyalRank(unlockedCount: 49, totalCount: 50).nextTitle, "全册封神")
        XCTAssertEqual(RoyalRank(unlockedCount: 49, totalCount: 50).nextThreshold, 50)

        let complete = RoyalRank(unlockedCount: 50, totalCount: 50)
        XCTAssertTrue(complete.isComplete)
        XCTAssertEqual(complete.title, "全册封神")
        XCTAssertNil(complete.nextThreshold)
        XCTAssertEqual(complete.progressInBand, 1)

        XCTAssertEqual(RoyalRank(unlockedCount: 0, totalCount: 0).level, 1)
    }

    private func stableMidday(reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }
}
