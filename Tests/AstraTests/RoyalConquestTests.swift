import XCTest
@testable import Astra

final class RoyalConquestTests: XCTestCase {
    func testLegendAndTerritoryThresholds() {
        XCTAssertEqual(CompanionLegendTier.resolve(hookupCount: 0), .none)
        XCTAssertEqual(CompanionLegendTier.resolve(hookupCount: 1), .first)
        XCTAssertEqual(CompanionLegendTier.resolve(hookupCount: 3), .returner)
        XCTAssertEqual(CompanionLegendTier.resolve(hookupCount: 5), .ace)
        XCTAssertEqual(CompanionLegendTier.resolve(hookupCount: 10), .legendary)

        XCTAssertEqual(TerritoryTier.resolve(hookupCount: 0), .none)
        XCTAssertEqual(TerritoryTier.resolve(hookupCount: 1), .conquered)
        XCTAssertEqual(TerritoryTier.resolve(hookupCount: 3), .outpost)
        XCTAssertEqual(TerritoryTier.resolve(hookupCount: 8), .stronghold)
        XCTAssertEqual(TerritoryTier.resolve(hookupCount: 15), .royalCity)
    }

    func testDashboardIgnoresMissesAndUsesActualEncounterLocation() throws {
        let companion = Companion(name: "她", cityID: "310000")
        let dates = [100.0, 200, 300, 400, 500].map { Date(timeIntervalSince1970: $0) }
        let encounters = [
            Encounter(companionID: companion.id, date: dates[0], kind: .intimacy, cityID: "110000"),
            Encounter(companionID: companion.id, date: dates[1], kind: .intimacy, cityID: "110000"),
            Encounter(companionID: companion.id, date: dates[2], kind: .intimacy, cityID: "110000"),
            Encounter(companionID: companion.id, date: dates[3], kind: .missed, cityID: "440100"),
        ]

        let dashboard = RoyalConquestEngine.build(
            companions: [companion],
            encounters: encounters,
            albumCount: { _ in 4 }
        )

        XCTAssertEqual(dashboard.legends.first?.tier, .returner)
        XCTAssertEqual(dashboard.legends.first?.privatePhotoCount, 4)
        XCTAssertEqual(dashboard.territories.map(\.locationID), ["110000"])
        XCTAssertEqual(dashboard.territories.first?.tier, .outpost)
        XCTAssertFalse(dashboard.territories.contains { $0.locationID == "440100" })
    }

    func testCampaignsBackfillNewConquestsAndPersonalRecords() throws {
        let first = Companion(name: "甲", cityID: "310000")
        let second = Companion(name: "乙", cityID: "110000")
        let calendar = Calendar(identifier: .gregorian)
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        let february = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 5)))
        let encounters = [
            Encounter(companionID: first.id, date: january, kind: .intimacy, cityID: "310000"),
            Encounter(companionID: first.id, date: february, kind: .intimacy, cityID: "310000"),
            Encounter(companionID: second.id, date: february.addingTimeInterval(10), kind: .intimacy, cityID: "110000"),
            Encounter(companionID: second.id, date: february.addingTimeInterval(20), kind: .intimacy, cityID: "110000"),
        ]

        let dashboard = RoyalConquestEngine.build(
            companions: [first, second],
            encounters: encounters,
            albumCount: { _ in 0 }
        )

        XCTAssertEqual(dashboard.monthlyCampaigns.count, 2)
        XCTAssertEqual(dashboard.monthlyCampaigns.first?.hookupCount, 3)
        XCTAssertEqual(dashboard.monthlyCampaigns.first?.newConquestCount, 1)
        XCTAssertEqual(dashboard.monthlyCampaigns.first?.newTerritoryCount, 1)
        XCTAssertEqual(dashboard.personalRecords.first { $0.metric == .monthHookups }?.value, 3)
        XCTAssertEqual(dashboard.yearlyCampaigns.first?.hookupCount, 4)
    }

    func testAnonymousSharePayloadHasNoPrivateFields() throws {
        let payload = AnonymousRoyalSharePayload(
            title: "猎艳王者",
            level: 4,
            companionCount: 12,
            hookupCount: 30,
            repeatCount: 3,
            territoryCount: 5,
            year: 2026,
            yearHookups: 8
        )
        let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)

        for forbidden in ["name", "photo", "location", "city", "date", "note", "coordinate", "cost", "health"] {
            XCTAssertFalse(json.lowercased().contains(forbidden), forbidden)
        }
    }

    @MainActor
    func testDirectSaveCreatesRewardsButDeleteDoesNot() {
        let suite = "AstraRoyalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        let companion = Companion(name: "她", cityID: "310000")
        store.save([companion], for: .companions)
        store.save([Encounter](), for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)
        let encounter = Encounter(companionID: companion.id, kind: .intimacy, cityID: "310000")

        app.upsert(encounter)

        XCTAssertTrue(app.pendingRewards.contains { $0.kind == .legendUpgrade })
        XCTAssertTrue(app.pendingRewards.contains { $0.kind == .territoryUpgrade })
        app.dismissRewards()
        app.delete(encounterID: encounter.id)
        XCTAssertTrue(app.pendingRewards.isEmpty)
    }
}
