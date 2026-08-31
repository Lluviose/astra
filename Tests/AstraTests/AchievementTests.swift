import XCTest
@testable import Astra

final class AchievementTests: XCTestCase {

    func testEmptyRosterUnlocksNothing() {
        let items = AchievementCatalog.evaluate(companions: [], encounters: [], cityCount: 0)
        XCTAssertFalse(items.contains(where: \.isUnlocked))
        XCTAssertEqual(items.count, 34)
        XCTAssertEqual(Set(items.map(\.id)).count, 34)
        XCTAssertEqual(Set(items.map(\.category)).count, AchievementCategory.allCases.count)
    }

    func testFirstGirlAndHookup() {
        let girl = Companion(name: "她")
        let hookup = Encounter(companionID: girl.id, kind: .intimacy)
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [hookup],
            cityCount: 1
        )

        XCTAssertTrue(unlocked(items, "first_girl"))
        XCTAssertTrue(unlocked(items, "first_hookup"))
        XCTAssertFalse(unlocked(items, "first_overnight"))
        XCTAssertFalse(unlocked(items, "hookups_3"))
        XCTAssertFalse(unlocked(items, "girls_3"))
    }

    func testOvernightAndPhotos() {
        let girl = Companion(name: "她", photoID: "avatar")
        let overnight = Encounter(companionID: girl.id, kind: .overnight, photoIDs: ["a", "b"])
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [overnight],
            cityCount: 1
        )

        XCTAssertTrue(unlocked(items, "first_overnight"))
        XCTAssertTrue(unlocked(items, "first_photo"))
        XCTAssertFalse(unlocked(items, "album_10"))
        XCTAssertEqual(items.first { $0.id == "album_10" }?.current, 3)
    }

    func testRegularAndDoubleHeader() {
        let girl = Companion(name: "固定", stage: .regular)
        let day = Date()
        let one = Encounter(companionID: girl.id, date: day, kind: .intimacy)
        let two = Encounter(companionID: girl.id, date: day.addingTimeInterval(3600), kind: .overnight)
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [one, two],
            cityCount: 1
        )

        XCTAssertTrue(unlocked(items, "regular"))
        XCTAssertTrue(unlocked(items, "double_header"))
        XCTAssertFalse(unlocked(items, "hat_trick"))
        XCTAssertFalse(unlocked(items, "hookups_3"))
        XCTAssertEqual(items.first { $0.id == "hookups_3" }?.current, 2)
    }

    func testRepeaterAndHatTrick() {
        let girl = Companion(name: "她")
        let day = Date()
        let encounters = (0..<3).map { offset in
            Encounter(
                companionID: girl.id,
                date: day.addingTimeInterval(TimeInterval(offset * 1800)),
                kind: .intimacy
            )
        }
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: encounters,
            cityCount: 1
        )
        XCTAssertTrue(unlocked(items, "repeater"))
        XCTAssertTrue(unlocked(items, "hat_trick"))
        XCTAssertTrue(unlocked(items, "hookups_3"))
        XCTAssertFalse(unlocked(items, "repeater_5"))
    }

    func testFirstTierAndCrossCity() {
        let girl = Companion(name: "她", cityID: "310000")
        let hookup = Encounter(companionID: girl.id, kind: .intimacy, cityID: "110000")
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [hookup],
            cityCount: 1
        )
        XCTAssertTrue(unlocked(items, "first_tier"))
        XCTAssertTrue(unlocked(items, "cross_city"))
    }

    func testWantAgainAndSexLogged() {
        let girl = Companion(name: "她")
        let encounter = Encounter(
            companionID: girl.id,
            kind: .intimacy,
            activities: [.vaginalPenetration],
            meetAgainIntent: .yes
        )
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [encounter],
            cityCount: 1
        )
        XCTAssertTrue(unlocked(items, "want_again"))
        XCTAssertTrue(unlocked(items, "sex_logged"))
        XCTAssertFalse(unlocked(items, "first_flirt"))
    }

    func testArchivedCompanionsDoNotCountAsActiveGirls() {
        let archived = Companion(name: "旧", isArchived: true)
        let items = AchievementCatalog.evaluate(companions: [archived], encounters: [], cityCount: 0)
        XCTAssertFalse(unlocked(items, "first_girl"))
    }

    func testChaptersStayInBookOrder() {
        let items = AchievementCatalog.evaluate(companions: [], encounters: [], cityCount: 0)
        XCTAssertEqual(items.first?.category, .hunt)
        XCTAssertEqual(items.last?.category, .play)
        XCTAssertEqual(items.first { $0.id == "hookups_50" }?.tier, .gold)
        XCTAssertEqual(items.first { $0.id == "first_girl" }?.tier, .bronze)
    }

    private func unlocked(_ items: [Achievement], _ id: String) -> Bool {
        items.first { $0.id == id }?.isUnlocked ?? false
    }
}
