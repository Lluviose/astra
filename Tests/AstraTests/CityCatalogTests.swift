import XCTest
@testable import Astra

final class CityCatalogTests: XCTestCase {

    private let catalog = CityCatalog.shared

    func testCatalogCoversPrefectureCities() {
        XCTAssertGreaterThan(catalog.cities.count, 330)
        XCTAssertEqual(Set(catalog.cities.map(\.id)).count, catalog.cities.count, "城市 id 必须唯一")
    }

    func testLegacyCitiesStillPresent() {
        XCTAssertEqual(catalog.city(id: "110000")?.name, "北京")
        XCTAssertEqual(catalog.city(id: "330100")?.name, "杭州")
        XCTAssertEqual(catalog.city(id: "810000")?.name, "香港")
    }

    func testPreviouslyMissingCitiesAreSearchable() {
        XCTAssertEqual(catalog.search("赣州").first?.name, "赣州")
        XCTAssertEqual(catalog.search("绵阳").first?.name, "绵阳")
        XCTAssertEqual(catalog.search("廊坊").first?.name, "廊坊")
        XCTAssertEqual(catalog.search("遵义").first?.name, "遵义")
        XCTAssertEqual(catalog.search("昆山").first?.name, "昆山")
        XCTAssertEqual(catalog.search("西双版纳").first?.name, "西双版纳")
        XCTAssertEqual(catalog.search("喀什").first?.name, "喀什")
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
        XCTAssertTrue(results.contains { $0.name == "义乌" })
    }

    func testCityLookup() {
        XCTAssertEqual(catalog.city(id: "110000")?.name, "北京")
        XCTAssertNil(catalog.city(id: "000000"))
    }

    func testCoordinatesStayInsideChina() {
        for city in catalog.cities {
            XCTAssertTrue(
                ChinaRegion.contains(latitude: city.lat, longitude: city.lon),
                "\(city.name) (\(city.lat), \(city.lon)) 超出中国包络框"
            )
        }
    }
}
