import XCTest

final class ModernUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.lluviose.astra.modern")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func tap(_ label: String) {
        let target = element(label)
        XCTAssertTrue(target.waitForExistence(timeout: 20), "Missing control: \(label)")
        target.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPagesAndRecordSurvivesRestart() throws {
        app.launch()
        XCTAssertTrue(element("打开精选人物档案").waitForExistence(timeout: 30))
        capture("01-collection")
        tap("打开精选人物档案")
        XCTAssertTrue(element("编辑人物").waitForExistence(timeout: 10))
        capture("02-person")
        tap("返回")

        tap("战绩")
        XCTAssertTrue(app.textFields["搜索战绩"].waitForExistence(timeout: 10))
        capture("03-journal")
        tap("殿堂")
        capture("04-hall")

        tap("新增记录")
        tap("选择林间")
        let title = app.textFields["片刻标题"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Native review note")
        app.swipeUp()
        let save = element("保存片刻")
        for _ in 0..<4 {
            if save.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(save.isHittable)
        capture("05-record")
        save.tap()
        XCTAssertTrue(element("新增记录").waitForExistence(timeout: 10))

        app.terminate()
        app.launch()
        XCTAssertTrue(element("新增记录").waitForExistence(timeout: 30))
        tap("战绩")
        let search = app.textFields["搜索战绩"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Native review note")
        XCTAssertTrue(app.staticTexts["Native review note"].waitForExistence(timeout: 10))
        app.swipeUp()
        capture("06-persisted-record")
    }
}
