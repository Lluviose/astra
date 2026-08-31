import XCTest
@testable import Astra

final class AchievementTests: XCTestCase {

    func testEmptyRosterUnlocksNothing() {
        let items = AchievementCatalog.evaluate(companions: [], encounters: [], cityCount: 0)
        XCTAssertFalse(items.contains(where: \.isUnlocked))
        XCTAssertEqual(items.count, 17)
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
        XCTAssertFalse(unlocked(items, "hookups_3"))
        XCTAssertEqual(items.first { $0.id == "hookups_3" }?.current, 2)
    }

    func testArchivedCompanionsDoNotCountAsActiveGirls() {
        let archived = Companion(name: "旧", isArchived: true)
        let items = AchievementCatalog.evaluate(companions: [archived], encounters: [], cityCount: 0)
        XCTAssertFalse(unlocked(items, "first_girl"))
    }

    private func unlocked(_ items: [Achievement], _ id: String) -> Bool {
        items.first { $0.id == id }?.isUnlocked ?? false
    }
}
