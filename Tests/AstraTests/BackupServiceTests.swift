import XCTest
@testable import Astra

final class BackupServiceTests: XCTestCase {

    func testEncodeDecodeRoundTrip() throws {
        let companion = Companion(
            name: "测试",
            cityID: "330100",
            stage: .dating,
            rating: 4,
            tags: ["温柔", "爱笑"],
            notes: "备注内容"
        )
        let encounter = Encounter(
            companionID: companion.id,
            date: Date(timeIntervalSince1970: 1_750_000_000),
            kind: .meal,
            place: "湖滨银泰",
            cost: 328,
            mood: 5
        )

        let data = try BackupService.encode(companions: [companion], encounters: [encounter])
        let decoded = try BackupService.decode(data)

        XCTAssertEqual(decoded.format, BackupService.formatIdentifier)
        XCTAssertEqual(decoded.companions.count, 1)
        XCTAssertEqual(decoded.companions.first?.name, "测试")
        XCTAssertEqual(decoded.companions.first?.stage, .dating)
        XCTAssertEqual(decoded.companions.first?.tags, ["温柔", "爱笑"])
        XCTAssertEqual(decoded.encounters.count, 1)
        XCTAssertEqual(decoded.encounters.first?.cost, 328)
        XCTAssertEqual(
            decoded.encounters.first?.date.timeIntervalSince1970,
            encounter.date.timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testRejectsForeignJSON() {
        let garbage = #"{"hello": "world"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try BackupService.decode(garbage)) { error in
            guard case BackupError.notAnAstraBackup = error else {
                return XCTFail("预期 notAnAstraBackup，实际 \(error)")
            }
        }
    }

    func testCompanionDecodesWithMissingOptionalFields() throws {
        // 旧版本备份里没有 tags / isArchived 等字段，导入不能失败
        let json = """
        {"id": "\(UUID().uuidString)", "name": "旧档案", "cityID": "310000"}
        """
        let companion = try JSONDecoder().decode(Companion.self, from: Data(json.utf8))
        XCTAssertEqual(companion.name, "旧档案")
        XCTAssertEqual(companion.stage, .talking)
        XCTAssertTrue(companion.tags.isEmpty)
        XCTAssertFalse(companion.isArchived)
        XCTAssertNil(companion.birthdayMonth)
    }
}
