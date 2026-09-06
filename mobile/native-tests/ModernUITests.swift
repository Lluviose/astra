import XCTest

final class ModernUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.lluviose.astra.modern")
    override func setUpWithError() throws { continueAfterFailure = false }

    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    private func top() {
        let scroll = app.scrollViews.firstMatch
        if scroll.exists { for _ in 0..<3 { scroll.swipeDown() } }
    }
    private func tap(_ label: String) {
        let target = element(label)
        for _ in 0..<7 {
            if target.exists && target.isHittable { break }
            if app.scrollViews.firstMatch.exists { app.scrollViews.firstMatch.swipeUp() }
        }
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing control: \(label)")
        XCTAssertTrue(target.isHittable, "Control is outside viewport: \(label)")
        target.tap()
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func launch() {
        app.launch()
        XCTAssertTrue(element("新增记录").waitForExistence(timeout: 30))
    }

    func test01EveryScreenDesignReview() throws {
        launch()
        XCTAssertTrue(element("山河，由此展开").waitForExistence(timeout: 20))
        capture("00-atlas")
        tap("放大沙盘")
        tap("定位所选城市")
        tap("重置沙盘")
        capture("00b-atlas-controls")
        tap("预览城市建筑")
        capture("00c-city-building")
        tap("返回全景沙盘")
        tap("人物")
        capture("01-collection")
        tap("隐藏私人内容")
        capture("01b-collection-hidden")
        tap("显示私人内容")
        app.scrollViews.firstMatch.swipeUp()
        capture("02-collection-detail")
        top()
        tap("打开精选人物档案")
        XCTAssertTrue(element("编辑人物").waitForExistence(timeout: 10))
        capture("03-person")
        tap("画像")
        app.scrollViews.firstMatch.swipeUp()
        capture("04-person-profile")
        top()
        tap("私藏")
        app.scrollViews.firstMatch.swipeUp()
        capture("05-person-album")
        tap("查看第1张私藏")
        XCTAssertTrue(element("关闭相册").waitForExistence(timeout: 10))
        capture("06-photo")
        tap("关闭相册")
        top()
        tap("编辑人物")
        capture("07-person-editor")
        tap("六维评分")
        app.scrollViews.firstMatch.swipeUp()
        capture("08-score-editor")
        tap("返回")
        tap("返回")
        tap("人物名册")
        capture("09-roster")
        tap("新建人物")
        capture("10-new-person")
        tap("返回")
        tap("返回")
        tap("战绩")
        XCTAssertTrue(app.textFields["搜索战绩"].waitForExistence(timeout: 10))
        capture("11-journal")
        tap("筛选记录")
        capture("12-journal-filters")
        tap("筛选记录")
        tap("成就")
        XCTAssertTrue(element("山河藏卷").waitForExistence(timeout: 10))
        capture("13-hall")
        app.scrollViews.firstMatch.swipeUp()
        capture("14-milestones")
        tap("偏爱排行")
        capture("15-ranking")
        tap("返回")
        tap("城市足迹")
        capture("16-footprints")
        tap("返回")
        top()
        tap("设置")
        capture("17-settings")
        app.scrollViews.firstMatch.swipeUp()
        capture("18-settings-detail")
        tap("返回")
        tap("新增记录")
        capture("19-record")
        tap("更多细节")
        capture("20-record-details")
    }

    func test02RecordSurvivesRestart() throws {
        launch()
        tap("新增记录")
        tap("选择林间")
        let title = app.textFields["片刻标题"]
        for _ in 0..<3 { if title.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Native review note")
        app.scrollViews.firstMatch.swipeUp()
        tap("保存片刻")
        XCTAssertTrue(element("新增记录").waitForExistence(timeout: 10))
        app.terminate()
        launch()
        tap("战绩")
        let search = app.textFields["搜索战绩"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Native review note")
        XCTAssertTrue(element("编辑记录：Native review note").waitForExistence(timeout: 10))
        app.scrollViews.firstMatch.swipeUp()
        capture("21-persisted-record")
        tap("编辑记录：Native review note")
        tap("删除这条记录")
        capture("22-delete-confirmation")
        tap("取消")
    }
    func test03EmptyStateDesignReview() throws {
        launch()
        tap("设置")
        tap("清空并开始自己的档案")
        tap("确认删除")
        XCTAssertTrue(element("新增记录").waitForExistence(timeout: 10))
        capture("23-empty-collection")
        tap("战绩")
        capture("24-empty-journal")
        tap("成就")
        capture("25-empty-hall")
        tap("设置")
        tap("载入示例内容")
        XCTAssertTrue(element("山河，由此展开").waitForExistence(timeout: 20))
    }
}
