import Foundation

/// 地点目录：中国使用城市粒度，境外只使用国家粒度。
///
/// 保留 `CityCatalog` / `city(id:)` 命名是为了兼容旧代码与备份；新界面应优先使用
/// `locations` 和 `location(id:)`。
struct CityCatalog: Sendable {

    /// 中国城市。
    let cities: [City]
    /// 境外国家级地点。
    let countries: [City]
    /// 全部可选地点。
    let locations: [City]
    private let index: [String: City]

    static let shared: CityCatalog = .load()

    init(cities: [City], countries: [City] = []) {
        let allLocations = cities + countries
        self.cities = cities
        self.countries = countries
        self.locations = allLocations
        self.index = Dictionary(allLocations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - 加载

    private struct Payload: Decodable {
        let cities: [City]
    }

    private struct CountryPayload: Decodable {
        let countries: [City]
    }

    static func load() -> CityCatalog {
        guard let cityURL = resourceURL(named: "cities") else {
            assertionFailure("cities.json 未打进 bundle，检查 project.yml 的 App/Resources 配置")
            return CityCatalog(cities: [])
        }
        let cities: [City]
        do {
            let cityData = try Data(contentsOf: cityURL)
            cities = try JSONDecoder().decode(Payload.self, from: cityData).cities
        } catch {
            assertionFailure("cities.json 解析失败: \(error)")
            return CityCatalog(cities: [])
        }

        guard let countryURL = resourceURL(named: "countries") else {
            assertionFailure("countries.json 未打进 bundle，境外国家将不可用")
            return CityCatalog(cities: cities)
        }
        do {
            let countryData = try Data(contentsOf: countryURL)
            let countries = try JSONDecoder().decode(CountryPayload.self, from: countryData).countries
            return CityCatalog(cities: cities, countries: countries)
        } catch {
            assertionFailure("countries.json 解析失败: \(error)")
            return CityCatalog(cities: cities)
        }
    }

    private static func resourceURL(named name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            return url
        }
        // 单元测试 / SwiftUI Preview 下 Bundle.main 可能不是宿主 App
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: name, withExtension: "json") {
                return url
            }
        }
        return nil
    }

    // MARK: - 查询

    func location(id: String) -> City? { index[id] }

    /// 兼容旧调用：境外国家 ID 也能被正常解析。
    func city(id: String) -> City? { location(id: id) }

    func locations(ids: some Sequence<String>) -> [City] { ids.compactMap { index[$0] } }

    /// 兼容旧调用。
    func cities(ids: some Sequence<String>) -> [City] { locations(ids: ids) }

    /// 支持「杭州」「hangzhou」「hz」「浙江」，也支持「美国」「meiguo」「USA」。
    func search(_ rawQuery: String, limit: Int = 80) -> [City] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty, limit > 0 else { return [] }

        let scored: [(City, Int)] = locations.compactMap { city in
            guard let rank = Self.rank(city: city, query: query) else { return nil }
            return (city, rank)
        }

        return scored
            .sorted {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                if $0.0.tier.rawValue != $1.0.tier.rawValue { return $0.0.tier.rawValue < $1.0.tier.rawValue }
                return $0.0.pinyin < $1.0.pinyin
            }
            .prefix(limit)
            .map(\.0)
    }

    /// 越小越靠前；nil 表示不匹配
    private static func rank(city: City, query: String) -> Int? {
        let pinyinTerms = city.pinyin.split(separator: " ").map(String.init)
        let abbreviationTerms = city.abbr.split(separator: " ").map(String.init)

        if city.name == query { return 0 }
        if city.isCountry, city.countryCode.lowercased() == query { return 0 }
        if abbreviationTerms.contains(query) { return 1 }
        if pinyinTerms.contains(query) { return 1 }
        if city.name.hasPrefix(query) { return 2 }
        if pinyinTerms.contains(where: { $0.hasPrefix(query) }) { return 3 }
        if abbreviationTerms.contains(where: { $0.hasPrefix(query) }) { return 4 }
        if city.name.contains(query) { return 5 }
        if pinyinTerms.contains(where: { $0.contains(query) }) { return 6 }
        if city.province.contains(query) { return 7 }
        return nil
    }
}
