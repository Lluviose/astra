import XCTest

final class NativeRedesignUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["collection-record"].waitForExistence(timeout: 15))
    }

    private func tab(_ title: String) {
        let native = app.tabBars.buttons[title].firstMatch
        let button = native.exists ? native : app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab: \(title)")
        button.tap()
        XCTAssertTrue(button.isSelected, "Tab did not become selected: \(title)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func openRoster() {
        let link = app.buttons["open-roster"]
        reveal(link)
        link.tap()
        XCTAssertTrue(app.navigationBars["名册"].waitForExistence(timeout: 5))
    }

    func testLightAppearanceAndDestinations() {
        launch()
        capture("01-collection-light")
        let featured = app.buttons["featured-dossier"]
        reveal(featured)
        featured.tap()
        XCTAssertTrue(app.navigationBars["林间"].waitForExistence(timeout: 5))
        capture("02-dossier-records")
        let sections = app.segmentedControls["dossier-section"]
        reveal(sections)
        sections.buttons["画像"].tap()
        capture("03-dossier-profile")
        sections.buttons["私藏"].tap()
        capture("04-dossier-album")
        tab("战绩")
        capture("05-journal-light")
        tab("殿堂")
        capture("06-hall-light")
        app.buttons["open-settings"].tap()
        XCTAssertTrue(app.buttons["close-settings"].waitForExistence(timeout: 5))
        capture("07-settings")
        app.buttons["close-settings"].tap()
    }

    func testDarkAppearance() {
        launch(["--ui-dark"])
        capture("08-collection-dark")
        tab("战绩")
        capture("09-journal-dark")
        tab("殿堂")
        capture("10-hall-dark")
    }

    func testAccessibilityTextAndFirstRecord() {
        launch(["--ui-large-type"])
        capture("11-collection-large-type")
        tab("战绩")
        XCTAssertTrue(app.buttons["new-record"].isHittable)
        capture("12-journal-large-type")
        app.terminate()
        launch(["--ui-empty"])
        capture("13-collection-empty")
        let first = app.buttons["first-record"]
        reveal(first)
        first.tap()
        let name = app.textFields["companion-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        capture("14-first-person")
        name.tap()
        name.typeText("First Memory")
        app.buttons["companion-save"].tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout: 5))
        capture("15-first-record")
    }

    func testPrivacyAndSearchRecovery() {
        launch()
        app.buttons["privacy-toggle"].tap()
        XCTAssertFalse(app.staticTexts["林间"].exists)
        capture("16-collection-hidden")
        openRoster()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("no-such-person")
        let reset = app.buttons["roster-reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        capture("17-search-empty")
        reveal(reset)
        reset.tap()
        XCTAssertFalse(app.staticTexts["没有符合条件的人"].exists)
        XCTAssertFalse(app.staticTexts["林间"].exists)
        capture("18-roster-hidden")
    }

    func testRecordCanBeSavedWithoutOptionalDetails() {
        launch()
        tab("战绩")
        app.buttons["new-record"].tap()
        let person = app.staticTexts["林间"].firstMatch
        XCTAssertTrue(person.waitForExistence(timeout: 5))
        person.tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout: 5))
        capture("19-record-essential")
        let note = app.descendants(matching: .any).matching(identifier: "record-note").firstMatch
        reveal(note)
        note.tap()
        note.typeText("UI review saved memory")
        app.buttons["record-save"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("UI review saved memory")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "UI review saved memory")).firstMatch.waitForExistence(timeout: 5))
        capture("20-record-saved")
    }

    func testMapCollectionAndAchievementsRemainReachable() {
        launch()
        tab("殿堂")
        let map = app.buttons["hall-map"]
        reveal(map)
        map.tap()
        let close = app.buttons["关闭足迹地图"]
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        capture("21-map")
        close.tap()
        let achievements = app.buttons["hall-achievements"]
        reveal(achievements)
        achievements.tap()
        capture("22-achievements")
        tab("后宫")
        let album = app.buttons["open-collection"]
        reveal(album)
        album.tap()
        XCTAssertTrue(app.navigationBars["私藏相册"].waitForExistence(timeout: 5))
        capture("23-photo-collection")
    }

    func testFollowUpCanBeCompletedAndUndone() {
        launch(["--ui-follow-up"])
        tab("战绩")
        app.buttons["journal-follow-ups"].tap()
        let complete = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "complete-follow-up-")).firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        let undo = app.buttons["undo-follow-up"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        capture("24-follow-up-completed")
        undo.tap()
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        capture("25-follow-up-restored")
    }

    func testSinglePersonSkipsPickerAndFiltersReset() {
        launch(["--ui-single-person"])
        tab("战绩")
        app.buttons["new-record"].tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["picker-new-person"].exists)
        app.buttons["record-cancel"].tap()
        app.buttons["journal-filter"].tap()
        XCTAssertTrue(app.navigationBars["筛选记录"].waitForExistence(timeout: 5))
        app.buttons["本月"].firstMatch.tap()
        app.buttons["journal-filter-done"].tap()
        let reset = app.buttons["journal-reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        capture("26-journal-filtered")
        reset.tap()
        XCTAssertFalse(reset.exists)
    }

    func testPrivateScoreSaveAndCancelRemainSeparate() {
        launch()
        let featured = app.buttons["featured-dossier"]
        reveal(featured)
        featured.tap()
        let sections = app.segmentedControls["dossier-section"]
        reveal(sections)
        sections.buttons["画像"].tap()
        let edit = app.buttons["edit-person-score"]
        reveal(edit)
        edit.tap()
        let looks = app.sliders["颜值"]
        XCTAssertTrue(looks.waitForExistence(timeout: 5))
        XCTAssertEqual(looks.value as? String, "6 分，共 10 分")
        app.buttons["忘不掉"].tap()
        capture("27-private-score")
        app.buttons["save-person-score"].tap()
        reveal(edit)
        edit.tap()
        XCTAssertTrue(looks.waitForExistence(timeout: 5))
        XCTAssertEqual(looks.value as? String, "9 分，共 10 分")
        app.buttons["有感觉"].tap()
        app.buttons["cancel-person-score"].tap()
        reveal(edit)
        edit.tap()
        XCTAssertTrue(looks.waitForExistence(timeout: 5))
        XCTAssertEqual(looks.value as? String, "9 分，共 10 分")
    }
}
