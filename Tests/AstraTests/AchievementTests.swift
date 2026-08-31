import XCTest
@testable import Astra

final class AchievementTests: XCTestCase {

    func testEmptyRosterUnlocksNothing() {
        let items = AchievementCatalog.evaluate(companions: [], encounters: [], cityCount: 0)
        XCTAssertFalse(items.contains(where: \.isUnlocked))
        XCTAssertEqual(items.count, 50)
        XCTAssertEqual(Set(items.map(\.id)).count, 50)
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
        XCTAssertEqual(items.first { $0.id == "album_10" }?.current, 2)
    }

    func testRegularAndDoubleHeader() {
        let girl = Companion(name: "固定", stage: .regular)
        let day = stableMidday()
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
        let day = stableMidday()
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
        XCTAssertFalse(unlocked(items, "bareback"))
        XCTAssertFalse(unlocked(items, "creampie"))
    }

    func testBarebackCreampieAndPlayDetails() {
        let girl = Companion(name: "她", stage: .prospect)
        let encounter = Encounter(
            companionID: girl.id,
            kind: .overnight,
            activities: [.cowgirl, .car, .multipleRounds],
            climaxDetails: [.creampie, .sheCame, .swallow],
            protectionStatus: .noProtection
        )
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [encounter],
            cityCount: 1
        )
        XCTAssertTrue(unlocked(items, "prospect"))
        XCTAssertTrue(unlocked(items, "bareback"))
        XCTAssertTrue(unlocked(items, "creampie"))
        XCTAssertTrue(unlocked(items, "swallow"))
        XCTAssertTrue(unlocked(items, "she_came"))
        XCTAssertTrue(unlocked(items, "cowgirl"))
        XCTAssertTrue(unlocked(items, "car_sex"))
        XCTAssertTrue(unlocked(items, "multi_round"))
        XCTAssertTrue(unlocked(items, "overnight_bareback"))
        XCTAssertFalse(unlocked(items, "facial"))
        XCTAssertFalse(unlocked(items, "bareback_5"))
        XCTAssertFalse(unlocked(items, "fwb"))
    }

    func testAlbumPhotosOnDossierCountTowardPrivateCollection() {
        let girl = Companion(name: "她", albumPhotoIDs: ["a", "b", "c"])
        let items = AchievementCatalog.evaluate(
            companions: [girl],
            encounters: [],
            cityCount: 0
        )
        XCTAssertTrue(unlocked(items, "first_photo"))
        XCTAssertEqual(items.first { $0.id == "album_10" }?.current, 3)
    }

    func testProfilePhotosDoNotCountTowardPrivateCollection() {
        let girl = Companion(name: "她", photoID: "avatar", profilePhotoIDs: ["profile"])
        let items = AchievementCatalog.evaluate(companions: [girl], encounters: [], cityCount: 0)
        XCTAssertFalse(unlocked(items, "first_photo"))
        XCTAssertEqual(items.first { $0.id == "album_10" }?.current, 0)
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

    func testNextUpPrefersStartedAndNearlyCompleteAchievements() {
        let items = [
            achievement(id: "untouched", current: 0, goal: 1),
            achievement(id: "started", current: 2, goal: 10),
            achievement(id: "closest", current: 4, goal: 5),
            achievement(id: "done", current: 1, goal: 1),
        ]

        XCTAssertEqual(
            AchievementCatalog.nextUp(in: items, limit: 3).map(\.id),
            ["closest", "started", "untouched"]
        )
    }

    func testNextUpUsesSmallestRemainingGoalForUntouchedAchievements() {
        let items = [
            achievement(id: "far", current: 0, goal: 10),
            achievement(id: "near", current: 0, goal: 1),
            achievement(id: "middle", current: 0, goal: 3),
        ]

        XCTAssertEqual(
            AchievementCatalog.nextUp(in: items, limit: 2).map(\.id),
            ["near", "middle"]
        )
    }

    func testNextUpDoesNotNudgeRiskEscalationAchievements() {
        let items = [
            achievement(id: "bareback_5", current: 4, goal: 5),
            achievement(id: "creampie_5", current: 4, goal: 5),
            achievement(id: "ordinary", current: 1, goal: 10),
        ]

        XCTAssertEqual(AchievementCatalog.nextUp(in: items).map(\.id), ["ordinary"])
    }

    private func unlocked(_ items: [Achievement], _ id: String) -> Bool {
        items.first { $0.id == id }?.isUnlocked ?? false
    }

    /// 固定在当前日历日的中午，避免 CI 恰好在 23 点运行时加时跨到次日。
    private func stableMidday(reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    private func achievement(id: String, current: Int, goal: Int) -> Achievement {
        Achievement(
            id: id,
            title: id,
            detail: "",
            story: "",
            symbolName: "sparkles",
            category: .hunt,
            tier: .bronze,
            red: 1,
            green: 0,
            blue: 0,
            current: current,
            goal: goal
        )
    }
}
