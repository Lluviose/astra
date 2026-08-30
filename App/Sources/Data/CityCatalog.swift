import Foundation

/// 城市目录：加载 `cities.json`，提供 ID 索引与中文 / 拼音 / 首字母搜索。
struct CityCatalog: Sendable {

    let cities: [City]
    private let index: [String: City]

    static let shared: CityCatalog = .load()

    init(cities: [City]) {
        self.cities = cities
        self.index = Dictionary(cities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - 加载

    private struct Payload: Decodable {
        let cities: [City]
    }

    static func load() -> CityCatalog {
        guard let url = resourceURL() else {
            assertionFailure("cities.json 未打进 bundle，检查 project.yml 的 App/Resources 配置")
            return CityCatalog(cities: [])
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            return CityCatalog(cities: payload.cities)
        } catch {
            assertionFailure("cities.json 解析失败: \(error)")
            return CityCatalog(cities: [])
        }
    }

    private static func resourceURL() -> URL? {
        if let url = Bundle.main.url(forResource: "cities", withExtension: "json") {
            return url
        }
        // 单元测试 / SwiftUI Preview 下 Bundle.main 可能不是宿主 App
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "cities", withExtension: "json") {
                return url
            }
        }
        return nil
    }

    // MARK: - 查询

    func city(id: String) -> City? { index[id] }

    func cities(ids: some Sequence<String>) -> [City] { ids.compactMap { index[$0] } }

    /// 支持「杭州」「hangzhou」「hz」「浙江」四种输入。
    func search(_ rawQuery: String, limit: Int = 40) -> [City] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }

        let scored: [(City, Int)] = cities.compactMap { city in
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
        if city.name == query { return 0 }
        if city.abbr == query { return 1 }
        if city.pinyin == query { return 1 }
        if city.name.hasPrefix(query) { return 2 }
        if city.pinyin.hasPrefix(query) { return 3 }
        if city.abbr.hasPrefix(query) { return 4 }
        if city.name.contains(query) { return 5 }
        if city.pinyin.contains(query) { return 6 }
        if city.province.contains(query) { return 7 }
        return nil
    }
}
