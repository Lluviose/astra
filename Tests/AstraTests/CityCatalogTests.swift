import XCTest
@testable import Astra

final class CityCatalogTests: XCTestCase {

    private let catalog = CityCatalog.shared

    func testCatalogCoversPrefectureCities() {
        XCTAssertGreaterThan(catalog.cities.count, 330)
        XCTAssertEqual(Set(catalog.cities.map(\.id)).count, catalog.cities.count, "城市 id 必须唯一")
    }

    func testCatalogIncludesMainstreamCountriesAtCountryLevelOnly() {
        XCTAssertGreaterThanOrEqual(catalog.countries.count, 80)
        XCTAssertEqual(
            Set(catalog.locations.map(\.id)).count,
            catalog.locations.count,
            "国家和城市 id 必须在整个目录内唯一"
        )
        XCTAssertTrue(catalog.countries.allSatisfy(\.isCountry))
        XCTAssertTrue(catalog.countries.allSatisfy { $0.id.range(of: #"^country:[A-Z]{2}$"#, options: .regularExpression) != nil })
        XCTAssertFalse(catalog.cities.contains(where: \.isCountry))
    }

    func testLegacyCitiesStillPresent() {
        XCTAssertEqual(catalog.location(id: "110000")?.name, "北京")
        XCTAssertEqual(catalog.location(id: "330100")?.name, "杭州")
        XCTAssertEqual(catalog.location(id: "810000")?.name, "香港")
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

    func testCountrySearchSupportsChinesePinyinEnglishAndISOCode() {
        XCTAssertEqual(catalog.search("美国").first?.id, "country:US")
        XCTAssertEqual(catalog.search("meiguo").first?.id, "country:US")
        XCTAssertEqual(catalog.search("unitedstates").first?.id, "country:US")
        XCTAssertEqual(catalog.search("USA").first?.id, "country:US")
        XCTAssertEqual(catalog.search("riben").first?.id, "country:JP")
        XCTAssertEqual(catalog.search("japan").first?.id, "country:JP")
    }

    func testCountryLookupUsesStableNamespacedID() {
        let country = catalog.location(id: "country:KR")
        XCTAssertEqual(country?.name, "韩国")
        XCTAssertEqual(country?.countryCode, "KR")
        XCTAssertEqual(country?.locationLevelLabel, "国家")
        XCTAssertNil(catalog.location(id: "KR"))
    }

    func testCountryCoordinatesNeverReceiveMainlandGCJOffset() throws {
        // 韩国的代表点落在旧粗略中国包络框内，国家级地点仍必须保持 WGS-84。
        let korea = try XCTUnwrap(catalog.location(id: "country:KR"))
        XCTAssertEqual(korea.displayCoordinate.latitude, korea.lat, accuracy: 1e-9)
        XCTAssertEqual(korea.displayCoordinate.longitude, korea.lon, accuracy: 1e-9)
    }

    func testCityLookup() {
        XCTAssertEqual(catalog.location(id: "110000")?.name, "北京")
        XCTAssertNil(catalog.location(id: "000000"))
    }

    func testSearchWithNonPositiveLimitReturnsEmptyInsteadOfTrapping() {
        XCTAssertTrue(catalog.search("杭州", limit: 0).isEmpty)
        XCTAssertTrue(catalog.search("杭州", limit: -1).isEmpty)
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
