import XCTest
@testable import Astra

final class CityCatalogTests: XCTestCase {

    private let catalog = CityCatalog.shared

    func testCatalogIsLoaded() {
        XCTAssertGreaterThan(catalog.cities.count, 60)
    }

    func testChineseSearch() {
        let results = catalog.search("杭州")
        XCTAssertEqual(results.first?.name, "杭州")
    }

    func testPinyinSearch() {
        let results = catalog.search("hangzhou")
        XCTAssertEqual(results.first?.id, "330100")
    }

    func testAbbreviationSearch() {
        let results = catalog.search("hz")
        XCTAssertEqual(results.first?.name, "杭州")
    }

    func testProvinceSearch() {
        let results = catalog.search("浙江")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.name == "杭州" })
        XCTAssertTrue(results.contains { $0.name == "宁波" })
    }

    func testCityLookup() {
        XCTAssertEqual(catalog.city(id: "110000")?.name, "北京")
        XCTAssertNil(catalog.city(id: "000000"))
    }
}
