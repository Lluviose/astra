import XCTest
@testable import Astra

final class MapInsightTests: XCTestCase {

    private func city(_ id: String, lat: Double, lon: Double) -> City {
        City(id: id, name: id, province: "测试", pinyin: id, abbr: id, tier: .other, lat: lat, lon: lon)
    }

    func testCountryFlagEmojiOnlyForForeignLocations() {
        XCTAssertEqual(city("country:JP", lat: 35, lon: 139).flagEmoji, "🇯🇵")
        XCTAssertEqual(city("country:us", lat: 38, lon: -97).flagEmoji, "🇺🇸")
        XCTAssertNil(city("310000", lat: 31, lon: 121).flagEmoji)
        XCTAssertNil(city("country:", lat: 0, lon: 0).flagEmoji)
    }

    @MainActor
    func testRouteDistanceSumsConsecutiveLegs() {
        let shanghai = city("310000", lat: 31.23, lon: 121.47)
        let beijing = city("110000", lat: 39.90, lon: 116.40)
        XCTAssertEqual(AppState.routeDistanceKM([]), 0)
        XCTAssertEqual(AppState.routeDistanceKM([shanghai]), 0)
        let oneLeg = AppState.routeDistanceKM([shanghai, beijing])
        XCTAssertEqual(oneLeg, 1_070, accuracy: 40)
        XCTAssertEqual(AppState.routeDistanceKM([shanghai, beijing, shanghai]), oneLeg * 2, accuracy: 0.001)
    }

    @MainActor
    func testYearFilterKeepsMembersButOnlyThatYearsRecords() throws {
        try withApp { app in
            let calendar = Calendar.current
            let her = Companion(name: "她", cityID: "310000")
            app.upsert(her)
            let thisYear = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12)) ?? Date()
            let lastYear = calendar.date(from: DateComponents(year: 2025, month: 7, day: 1, hour: 12)) ?? Date()
            app.upsert(Encounter(companionID: her.id, date: thisYear, kind: .intimacy, cityID: "310000"))
            app.upsert(Encounter(companionID: her.id, date: lastYear, kind: .intimacy, cityID: "110000"))

            XCTAssertEqual(app.hookupYears, [2026, 2025])
            XCTAssertEqual(app.conquestLocationPath(inYear: 2025).map(\.id), ["110000"])
            XCTAssertEqual(app.conquestLocationPath().map(\.id), ["110000", "310000"])

            let filtered = app.buckets(inYear: 2025)
            let shanghai = try XCTUnwrap(filtered.first { $0.id == "310000" })
            XCTAssertEqual(shanghai.hookupCount, 0)
            XCTAssertEqual(shanghai.companions.map(\.id), [her.id])
            let beijing = try XCTUnwrap(filtered.first { $0.id == "110000" })
            XCTAssertEqual(beijing.hookupCount, 1)
            XCTAssertEqual(app.buckets(inYear: nil).map(\.id).sorted(), app.buckets.map(\.id).sorted())
        }
    }

    @MainActor
    private func withApp(_ action: (AppState) throws -> Void) rethrows {
        let suiteName = "MapInsightTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LocalStore(defaults: defaults)
        store.save([Companion](), for: .companions)
        store.save([Encounter](), for: .encounters)
        try action(AppState(store: store, catalog: .shared, performsMediaMaintenance: false))
    }
}
