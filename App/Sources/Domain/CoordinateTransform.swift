import CoreLocation
import Foundation

/// 中国大陆地图坐标系转换。
///
/// 背景：公开数据集（含本项目 `cities.json`）通常是 WGS-84 大地坐标，
/// 而中国大陆境内发布的电子地图（含 Apple Maps 在中国区的底图）使用 GCJ-02 加密坐标。
/// 直接把 WGS-84 坐标交给 MapKit 渲染，会出现约 300～600m 的系统性偏移——
/// 在城市级别的标注上表现为「大头针落在隔壁区」。
///
/// 因此：**存储用 WGS-84，渲染前统一转 GCJ-02。**
/// 另注意 `CLLocationManager` 在中国大陆返回的已经是 GCJ-02，无需二次转换。
enum CoordinateTransform {

    // 克拉索夫斯基椭球参数（GCJ-02 算法沿用）
    private static let a = 6_378_245.0
    private static let ee = 0.006_693_421_622_965_943

    /// 粗略判断是否在中国大陆经纬度包络框内。框外不做偏移（港澳台及境外按原坐标处理）。
    static func isOutOfChina(latitude: Double, longitude: Double) -> Bool {
        !(longitude > 73.66 && longitude < 135.05 && latitude > 3.86 && latitude < 53.55)
    }

    /// WGS-84 → GCJ-02
    static func wgs84ToGCJ02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        guard !isOutOfChina(latitude: latitude, longitude: longitude) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        let (dLat, dLon) = offset(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2D(latitude: latitude + dLat, longitude: longitude + dLon)
    }

    static func wgs84ToGCJ02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        wgs84ToGCJ02(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// GCJ-02 → WGS-84（数值迭代反解，5 次迭代即可收敛到厘米级）
    static func gcj02ToWGS84(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        guard !isOutOfChina(latitude: latitude, longitude: longitude) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        var lat = latitude
        var lon = longitude
        for _ in 0..<5 {
            let guess = wgs84ToGCJ02(latitude: lat, longitude: lon)
            lat += latitude - guess.latitude
            lon += longitude - guess.longitude
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static func gcj02ToWGS84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        gcj02ToWGS84(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    // MARK: - 偏移量

    private static func offset(latitude: Double, longitude: Double) -> (Double, Double) {
        let x = longitude - 105.0
        let y = latitude - 35.0
        var dLat = transformLatitude(x: x, y: y)
        var dLon = transformLongitude(x: x, y: y)

        let radLat = latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return (dLat, dLon)
    }

    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}
