import XCTest
@testable import Astra

final class PeriodCycleTests: XCTestCase {

    private var calendar: Calendar { .current }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func record(
        _ companion: UUID,
        start: Date,
        end: Date? = nil,
        flow: PeriodFlow = .medium
    ) -> PeriodRecord {
        PeriodRecord(companionID: companion, startDate: start, endDate: end, flow: flow)
    }

    func testRegularCyclesPredictNextStartAndOvulation() {
        let id = UUID()
        let records = [
            record(id, start: day(2026, 1, 1), end: day(2026, 1, 5)),
            record(id, start: day(2026, 1, 29), end: day(2026, 2, 2)),
            record(id, start: day(2026, 2, 26), end: day(2026, 3, 2)),
            record(id, start: day(2026, 3, 26), end: day(2026, 3, 30)),
        ]
        let asOf = day(2026, 4, 9)
        let forecast = CycleEngine.forecast(records: records, asOf: asOf, calendar: calendar)

        XCTAssertEqual(forecast.cycleDays, 28)
        XCTAssertEqual(forecast.periodDays, 5)
        XCTAssertEqual(forecast.lutealDays, 14)
        XCTAssertEqual(forecast.nextStart, day(2026, 4, 23))
        XCTAssertEqual(forecast.ovulation, day(2026, 4, 9))
        XCTAssertEqual(forecast.confidence, .medium)
        XCTAssertEqual(
            CycleEngine.phase(on: asOf, records: records, forecast: forecast, calendar: calendar),
            .ovulation
        )
        XCTAssertEqual(
            CycleEngine.phase(on: day(2026, 4, 10), records: records, forecast: forecast, calendar: calendar),
            .fertile
        )
    }

    func testSpottingDoesNotStartANewCycle() {
        let id = UUID()
        let records = [
            record(id, start: day(2026, 1, 1), end: day(2026, 1, 5)),
            record(id, start: day(2026, 1, 14), end: day(2026, 1, 14), flow: .spotting),
            record(id, start: day(2026, 1, 29), end: day(2026, 2, 2)),
        ]
        let episodes = CycleEngine.episodes(from: records, asOf: day(2026, 2, 10), calendar: calendar)
        XCTAssertEqual(episodes.filter(\.isPeriod).count, 2)
        XCTAssertEqual(episodes.filter { !$0.isPeriod }.count, 1)

        let forecast = CycleEngine.forecast(records: records, asOf: day(2026, 2, 10), calendar: calendar)
        XCTAssertEqual(forecast.cycleDays, 28)
        XCTAssertEqual(forecast.sampleCount, 1)
    }

    func testAdjacentBleedsMergeIntoOneEpisode() {
        let id = UUID()
        let records = [
            record(id, start: day(2026, 3, 1), end: day(2026, 3, 2), flow: .light),
            record(id, start: day(2026, 3, 4), end: day(2026, 3, 6), flow: .heavy),
        ]
        let episodes = CycleEngine.episodes(from: records, asOf: day(2026, 3, 10), calendar: calendar)
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].start, day(2026, 3, 1))
        XCTAssertEqual(episodes[0].end, day(2026, 3, 6))
        XCTAssertEqual(episodes[0].flow, .heavy)
        XCTAssertTrue(episodes[0].isPeriod)
    }

    func testLongGapIsDroppedAsOutlier() {
        let id = UUID()
        let records = [
            record(id, start: day(2025, 6, 1), end: day(2025, 6, 5)),
            record(id, start: day(2025, 6, 29), end: day(2025, 7, 3)),
            record(id, start: day(2025, 7, 27), end: day(2025, 7, 31)),
            record(id, start: day(2025, 10, 1), end: day(2025, 10, 5)),
            record(id, start: day(2025, 10, 29), end: day(2025, 11, 2)),
        ]
        let forecast = CycleEngine.forecast(records: records, asOf: day(2025, 11, 10), calendar: calendar)
        XCTAssertEqual(forecast.cycleDays, 28)
        XCTAssertGreaterThanOrEqual(forecast.outlierCount, 1)
        XCTAssertEqual(forecast.nextStart, day(2025, 11, 26))
    }

    func testRecentRegimeShiftFollowsNewLength() {
        let id = UUID()
        let starts = [
            day(2025, 1, 1),
            day(2025, 1, 29),
            day(2025, 2, 26),
            day(2025, 3, 26),
            day(2025, 4, 30),
            day(2025, 6, 4),
            day(2025, 7, 9),
        ]
        let records = starts.map { record(id, start: $0, end: calendar.date(byAdding: .day, value: 4, to: $0)) }
        let forecast = CycleEngine.forecast(records: records, asOf: day(2025, 7, 20), calendar: calendar)
        XCTAssertTrue(forecast.regimeShifted)
        XCTAssertEqual(forecast.cycleDays, 35)
        XCTAssertEqual(forecast.nextStart, day(2025, 8, 13))
    }

    func testLatePeriodWidensWindow() {
        let id = UUID()
        let records = [
            record(id, start: day(2026, 1, 1), end: day(2026, 1, 5)),
            record(id, start: day(2026, 1, 29), end: day(2026, 2, 2)),
            record(id, start: day(2026, 2, 26), end: day(2026, 3, 2)),
        ]
        let onTime = CycleEngine.forecast(records: records, asOf: day(2026, 3, 20), calendar: calendar)
        let late = CycleEngine.forecast(records: records, asOf: day(2026, 4, 5), calendar: calendar)
        XCTAssertEqual(onTime.nextStart, day(2026, 3, 26))
        XCTAssertGreaterThan(late.windowRadius, onTime.windowRadius)
        XCTAssertEqual(
            CycleEngine.phase(on: day(2026, 4, 5), records: records, forecast: late, calendar: calendar),
            .late
        )
    }

    func testOpenPeriodCountsAsStillBleeding() {
        let id = UUID()
        let records = [record(id, start: day(2026, 4, 1), end: nil)]
        let asOf = day(2026, 4, 3)
        let snapshot = CycleEngine.snapshot(
            trackingEnabled: true,
            records: records,
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(snapshot.phase, .bleeding)
        XCTAssertEqual(snapshot.dayOfPeriod, 3)
        XCTAssertNotNil(snapshot.openRecord)
    }

    func testPriorHelpsWhenOnlyOneCycleExists() {
        let id = UUID()
        let records = [record(id, start: day(2026, 3, 1), end: day(2026, 3, 5))]
        let forecast = CycleEngine.forecast(
            records: records,
            typicalCycleDays: 30,
            asOf: day(2026, 3, 10),
            calendar: calendar
        )
        XCTAssertEqual(forecast.cycleDays, 30)
        XCTAssertEqual(forecast.nextStart, day(2026, 3, 31))
        XCTAssertEqual(forecast.confidence, .none)
    }

    func testDisabledTrackingHasNoHeadlinePrediction() {
        let snapshot = CycleEngine.snapshot(
            trackingEnabled: false,
            records: [],
            asOf: day(2026, 4, 1),
            calendar: calendar
        )
        XCTAssertFalse(snapshot.isTracking)
        XCTAssertEqual(snapshot.phase, .unknown)
        XCTAssertFalse(snapshot.needsHomeAttention)
    }

    func testWeightedMedianPrefersRecentValues() {
        let items = [
            (value: 40, weight: 0.2),
            (value: 28, weight: 1.0),
            (value: 28, weight: 0.8),
        ]
        XCTAssertEqual(CycleEngine.weightedMedian(items), 28)
    }

    func testLutealLengthTracksCycleBand() {
        XCTAssertEqual(CycleEngine.lutealDays(forCycle: 22), 12)
        XCTAssertEqual(CycleEngine.lutealDays(forCycle: 28), 14)
        XCTAssertEqual(CycleEngine.lutealDays(forCycle: 40), 16)
    }

    func testBackupRejectsPeriodRecordForUnknownCompanion() throws {
        let stranger = PeriodRecord(companionID: UUID(), startDate: day(2026, 1, 1), endDate: day(2026, 1, 5))
        let data = try BackupService.encode(
            companions: [Companion(name: "她")],
            encounters: [],
            periodRecords: [stranger]
        )
        XCTAssertThrowsError(try BackupService.decode(data)) { error in
            guard case BackupError.invalidContents = error else {
                return XCTFail("预期 invalidContents，实际 \(error)")
            }
        }
    }

    func testPeriodRecordsRoundTripThroughBackup() throws {
        let companion = Companion(name: "她", periodTrackingEnabled: true, typicalCycleDays: 28)
        let record = PeriodRecord(
            companionID: companion.id,
            startDate: Date(timeIntervalSince1970: 1_750_000_000),
            endDate: Date(timeIntervalSince1970: 1_750_345_600),
            flow: .heavy,
            symptoms: [.cramps, .fatigue],
            notes: "量偏大"
        )
        let data = try BackupService.encode(
            companions: [companion],
            encounters: [],
            periodRecords: [record]
        )
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded.version, 6)
        XCTAssertEqual(decoded.periodRecords.count, 1)
        XCTAssertEqual(decoded.periodRecords.first?.flow, .heavy)
        XCTAssertEqual(decoded.periodRecords.first?.symptoms, [.cramps, .fatigue])
        XCTAssertEqual(decoded.companions.first?.typicalCycleDays, 28)
        XCTAssertTrue(decoded.companions.first?.periodTrackingEnabled == true)
    }

    func testOldBackupWithoutPeriodRecordsStillDecodes() throws {
        let companion = Companion(name: "她")
        var payload = try JSONSerialization.jsonObject(
            with: BackupService.encode(companions: [companion], encounters: [])
        ) as? [String: Any]
        payload?["version"] = 5
        payload?["periodRecords"] = nil
        let data = try JSONSerialization.data(withJSONObject: payload ?? [:])
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded.version, 5)
        XCTAssertTrue(decoded.periodRecords.isEmpty)
    }
}

final class PeriodStoreTests: XCTestCase {

    @MainActor
    func testMarkStartedAndEndedRoundTrip() {
        let (defaults, suiteName) = makePeriodDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LocalStore(defaults: defaults)
        let companion = Companion(name: "她", periodTrackingEnabled: true)
        store.save([companion], for: .companions)
        store.save([Encounter](), for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        let started = app.markPeriodStarted(for: companion.id, on: Date(timeIntervalSince1970: 1_750_000_000))
        XCTAssertEqual(app.periodRecords.count, 1)
        XCTAssertNil(started?.endDate)
        XCTAssertTrue(app.companion(id: companion.id)?.periodTrackingEnabled == true)

        let ended = app.markPeriodEnded(for: companion.id, on: Date(timeIntervalSince1970: 1_750_259_200))
        XCTAssertNotNil(ended?.endDate)
        XCTAssertEqual(app.periodRecords.count, 1)
    }

    @MainActor
    func testDeleteCompanionRemovesPeriodRecords() {
        let (defaults, suiteName) = makePeriodDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LocalStore(defaults: defaults)
        let companion = Companion(name: "她", periodTrackingEnabled: true)
        store.save([companion], for: .companions)
        store.save([Encounter](), for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)
        _ = app.markPeriodStarted(for: companion.id)
        XCTAssertEqual(app.periodRecords.count, 1)

        app.delete(companionID: companion.id)
        XCTAssertTrue(app.periodRecords.isEmpty)
    }

    @MainActor
    func testMergeImportKeepsNewerPeriodRecord() throws {
        let (defaults, suiteName) = makePeriodDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LocalStore(defaults: defaults)
        let companion = Companion(name: "她", periodTrackingEnabled: true)
        var local = PeriodRecord(companionID: companion.id, startDate: Date(timeIntervalSince1970: 1_750_000_000), flow: .light)
        local.updatedAt = Date(timeIntervalSince1970: 2_000)
        store.save([companion], for: .companions)
        store.save([Encounter](), for: .encounters)
        store.save([local], for: .periodRecords)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        var incoming = local
        incoming.flow = .heavy
        incoming.notes = "备份较新"
        incoming.updatedAt = Date(timeIntervalSince1970: 3_000)
        let data = try BackupService.encode(
            companions: [companion],
            encounters: [],
            periodRecords: [incoming]
        )
        let summary = try app.importBackup(data, replaceExisting: false)
        XCTAssertEqual(summary.periodRecordsUpdated, 1)
        XCTAssertEqual(app.periodRecords.first?.flow, .heavy)
        XCTAssertEqual(app.periodRecords.first?.notes, "备份较新")
    }
}

private func makePeriodDefaults() -> (UserDefaults, String) {
    let suiteName = "astra.period.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
}
