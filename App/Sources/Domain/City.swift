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

/// 中国城市。坐标以 WGS-84 存储，渲染前转 GCJ-02。
struct City: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let province: String
    let pinyin: String
    let abbr: String
    let tier: CityTier
    let lat: Double
    let lon: Double

    /// 原始 WGS-84 坐标（距离计算用）
    var wgs84: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 交给 MapKit 渲染的 GCJ-02 坐标
    var displayCoordinate: CLLocationCoordinate2D {
        CoordinateTransform.wgs84ToGCJ02(latitude: lat, longitude: lon)
    }

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
