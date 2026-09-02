import CoreLocation
import Foundation

enum CityTier: Int, Codable, CaseIterable, Sendable {
    case first = 1
    case newFirst = 2
    case second = 3
    case other = 4

    var label: String {
        switch self {
        case .first: "一线"
        case .newFirst: "新一线"
        case .second: "二线"
        case .other: "其他"
        }
    }
}

/// 可记录的地点。中国精确到城市，境外只提供国家级地点。
///
/// `country:XX` 是境外国家的稳定 ID；原有的六位行政区 ID 仍表示中国城市，
/// 因此旧备份不需要做数据迁移。坐标均以 WGS-84 存储。
struct City: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let province: String
    let pinyin: String
    let abbr: String
    let tier: CityTier
    let lat: Double
    let lon: Double

    /// 境外国家使用 `country:US` 这类 ID，不允许继续细分省市。
    var isCountry: Bool { id.hasPrefix("country:") }

    /// ISO 3166-1 alpha-2 代码；中国城市统一返回 `CN`。
    var countryCode: String {
        guard isCountry else { return "CN" }
        return String(id.dropFirst("country:".count)).uppercased()
    }

    var locationLevelLabel: String { isCountry ? "国家" : "城市" }

    /// 用于选择器和详情页的辅助说明。境外不暴露一个虚构的“城市等级”。
    var locationSubtitle: String {
        return isCountry
            ? "\(province) · \(countryCode) · 仅记录到国家"
            : "\(shortProvince) · \(pinyin)"
    }

    /// 原始 WGS-84 坐标（距离计算用）
    var wgs84: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 交给 MapKit 渲染的坐标。境外国家代表点明确透传 WGS-84。
    var displayCoordinate: CLLocationCoordinate2D {
        guard !isCountry else { return wgs84 }
        return CoordinateTransform.wgs84ToGCJ02(latitude: lat, longitude: lon)
    }

    /// 国家级地点需要更宽的聚焦范围。
    var focusSpanDegrees: Double { isCountry ? 20 : 2.4 }

    /// 「广东省」→「广东」；直辖市与特别行政区保持原样
    var shortProvince: String {
        for suffix in ["维吾尔自治区", "壮族自治区", "回族自治区", "自治区", "特别行政区", "省"]
        where province.hasSuffix(suffix) {
            return String(province.dropLast(suffix.count))
        }
        return province
    }

    /// 与另一座城市的直线距离（米）
    func distance(to other: City) -> CLLocationDistance {
        CLLocation(latitude: lat, longitude: lon)
            .distance(from: CLLocation(latitude: other.lat, longitude: other.lon))
    }
}
