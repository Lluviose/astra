import XCTest
@testable import Astra

final class JournalWorkflowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testPeriodBoundariesExcludeNextMonthAndNextYear() {
        let now = date(2026, 12, 20)
        XCTAssertTrue(RecordPeriod.month.contains(date(2026, 12, 1, 0), now: now, calendar: calendar))
        XCTAssertFalse(RecordPeriod.month.contains(date(2027, 1, 1, 0), now: now, calendar: calendar))
        XCTAssertTrue(RecordPeriod.year.contains(date(2026, 1, 1, 0), now: now, calendar: calendar))
        XCTAssertFalse(RecordPeriod.year.contains(date(2027, 1, 1, 0), now: now, calendar: calendar))
    }

    func testNinetyDayRangeIncludesTodayAndEightyNinePreviousDays() {
        let today = date(2026, 9, 5, 0)
        let first = calendar.date(byAdding: .day, value: -89, to: today)!
        XCTAssertTrue(RecordPeriod.quarter.contains(first, now: today, calendar: calendar))
        XCTAssertFalse(RecordPeriod.quarter.contains(first.addingTimeInterval(-1), now: today, calendar: calendar))
        XCTAssertFalse(RecordPeriod.quarter.contains(date(2026, 9, 6, 0), now: today, calendar: calendar))
    }

    func testSearchPersonOutcomeAndPeriodIntersect() {
        let first = Companion(name: "林间", tags: ["咖啡"])
        let second = Companion(name: "南风")
        let match = Encounter(companionID: first.id, date: date(2026, 9, 3), kind: .intimacy, note: "A Quiet evening")
        let records = [match,
            Encounter(companionID: second.id, date: date(2026, 9, 3), kind: .intimacy, note: "quiet"),
            Encounter(companionID: first.id, date: date(2026, 9, 3), kind: .missed, note: "quiet"),
            Encounter(companionID: first.id, date: date(2026, 8, 3), kind: .intimacy, note: "quiet")]
        let filter = JournalFilter(query: " QUIET ", period: .month, scope: .intimate, companionID: first.id)
        XCTAssertEqual(filter.apply(to: records, companions: [first, second], locationName: { _ in "上海" }, now: date(2026, 9, 5), calendar: calendar).map(\.id), [match.id])
        XCTAssertTrue(filter.isActive)
    }

    @MainActor
    func testEmptyCollectionStartsWithIdentityAndCancellationCreatesNothing() {
        withState { app, _ in
            let flow = RecordingFlow()
            flow.begin(kind: .intimacy, app: app)
            XCTAssertEqual(flow.companionEditorTarget?.cityID, "")
            XCTAssertFalse(flow.isPickingCompanion)
            flow.finishCompanionEditor(app: app)
            XCTAssertNil(flow.encounterTarget)
            XCTAssertTrue(app.companions.isEmpty)
            XCTAssertTrue(app.encounters.isEmpty)
        }
    }

    @MainActor
    func testSinglePersonSkipsPickerAndUnknownLocationRemainsUnspecified() {
        withState { app, _ in
            let person = Companion(name: "林间", cityID: "")
            app.upsert(person)
            let flow = RecordingFlow()
            flow.begin(kind: .missed, app: app)
            XCTAssertFalse(flow.isPickingCompanion)
            XCTAssertEqual(flow.encounterTarget?.companionID, person.id)
            XCTAssertEqual(flow.encounterTarget?.kind, .missed)
            XCTAssertNil(flow.encounterTarget?.cityID)
        }
    }

    @MainActor
    func testNewPersonFromPickerContinuesOnlyAfterIdentityIsSaved() {
        withState { app, _ in
            app.upsert(Companion(name: "甲"))
            app.upsert(Companion(name: "乙"))
            let flow = RecordingFlow()
            flow.begin(kind: .intimacy, app: app)
            XCTAssertTrue(flow.isPickingCompanion)
            flow.requestNewCompanion()
            flow.finishCompanionPicker(app: app)
            guard var person = flow.companionEditorTarget else { return XCTFail("Expected identity editor") }
            person.name = "新人物"
            app.upsert(person)
            flow.finishCompanionEditor(app: app)
            XCTAssertEqual(flow.encounterTarget?.companionID, person.id)
            XCTAssertEqual(app.encounters.count, 0)
        }
    }

    @MainActor
    func testFollowUpCompletionAndUndoPreserveOriginalRecord() {
        withState { app, store in
            let person = Companion(name: "甲")
            app.upsert(person)
            // LocalStore uses ISO-8601 second precision; keep this fixture at that precision.
            let record = Encounter(companionID: person.id, date: date(2026, 9, 5), kind: .intimacy,
                                   followUpKinds: [.message], followUpDate: date(2026, 9, 6),
                                   followUpNote: "明晚联系", note: "原始记录")
            app.upsert(record)
            app.setFollowUpDone(true, for: record.id)
            XCTAssertTrue(app.pendingFollowUps.isEmpty)
            let loaded = AppState(store: store, performsMediaMaintenance: false)
            XCTAssertTrue(loaded.encounters.first?.isFollowUpDone == true)
            XCTAssertEqual(loaded.encounters.first?.note, record.note)
            XCTAssertEqual(loaded.encounters.first?.date, record.date)
            loaded.setFollowUpDone(false, for: record.id)
            XCTAssertEqual(loaded.pendingFollowUps.map(\.id), [record.id])
            XCTAssertEqual(loaded.encounters.count, 1)
        }
    }

    @MainActor
    private func withState(_ work: (AppState, LocalStore) -> Void) {
        let suite = "AstraJournalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        work(AppState(store: store, performsMediaMaintenance: false), store)
    }
}
