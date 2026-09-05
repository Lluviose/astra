import XCTest

final class NativeRedesignUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) {
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["home-record"].waitForExistence(timeout: 15))
    }

    private func tab(_ title: String) {
        let nativeTab = app.tabBars.buttons[title].firstMatch
        let button = nativeTab.exists ? nativeTab : app.buttons[title].firstMatch
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
        for _ in 0..<8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    func testLightAppearanceAndDestinations() {
        launch()
        capture("01-home-light")
        tab("名册")
        capture("02-roster-light")
        let person = app.staticTexts["林间"].firstMatch
        reveal(person)
        person.tap()
        XCTAssertTrue(app.navigationBars["林间"].waitForExistence(timeout: 5))
        capture("03-dossier-light")
        tab("时间线")
        capture("04-timeline-light")
        tab("成就册")
        capture("05-achievements-light")
        tab("设置")
        capture("06-settings-light")
    }

    func testDarkAppearance() {
        launch(["--ui-dark"])
        capture("07-home-dark")
        tab("名册")
        capture("08-roster-dark")
        tab("时间线")
        capture("09-timeline-dark")
    }

    func testAccessibilityTextAndEmptyState() {
        launch(["--ui-large-type"])
        capture("10-home-large-type")
        reveal(app.buttons["home-record"])
        XCTAssertTrue(app.buttons["home-record"].isHittable)
        tab("名册")
        capture("11-roster-large-type")
        app.terminate()
        launch(["--ui-empty"])
        capture("12-home-empty")
        app.buttons["home-record"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        capture("13-first-record-location")
    }

    func testPrivacyAndSearchRecovery() {
        launch()
        app.buttons["privacy-toggle"].tap()
        tab("名册")
        XCTAssertFalse(app.staticTexts["林间"].exists)
        XCTAssertTrue(app.staticTexts["代号已隐藏"].firstMatch.exists)
        capture("14-privacy-masked")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("no-such-person")
        let clear = app.buttons["roster-reset"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        capture("14b-search-empty")
        reveal(clear)
        clear.tap()
        XCTAssertFalse(app.staticTexts["没有符合条件的人"].exists)
    }

    func testRecordCanBeSavedWithoutOptionalDetails() {
        launch()
        app.buttons["home-record"].tap()
        let person = app.staticTexts["林间"].firstMatch
        XCTAssertTrue(person.waitForExistence(timeout: 5))
        person.tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout: 5))
        capture("15-record-essential")
        let note = app.descendants(matching: .any).matching(identifier: "record-note").firstMatch
        reveal(note)
        note.tap()
        note.typeText("UI review saved memory")
        app.buttons["record-save"].tap()
        for identifier in ["dismiss-rewards", "dismiss-unlocks"] {
            let dismiss = app.buttons[identifier]
            if dismiss.waitForExistence(timeout: 5) {
                dismiss.tap()
                let gone = NSPredicate(format: "exists == false")
                expectation(for: gone, evaluatedWith: dismiss)
                waitForExpectations(timeout: 5)
            }
        }
        tab("时间线")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("UI review saved memory")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "UI review saved memory")).firstMatch.waitForExistence(timeout: 5))
        capture("16-record-saved")
    }

    func testMapAndCollectionRemainReachable() {
        launch()
        let map = app.buttons["home-map"]
        reveal(map)
        map.tap()
        let close = app.buttons["关闭足迹地图"]
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        capture("17-map")
        close.tap()
        tab("名册")
        app.staticTexts["私人图鉴"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["私人图鉴"].waitForExistence(timeout: 5))
        capture("18-collection")
    }
}
