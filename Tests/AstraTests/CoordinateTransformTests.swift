import CoreLocation
import XCTest
@testable import Astra

final class CoordinateTransformTests: XCTestCase {

    func testKnownBeijingOffset() {
        // 北京天安门 WGS-84 → GCJ-02 的公认偏移量约为 (-0.005, +0.003)
        let gcj = CoordinateTransform.wgs84ToGCJ02(latitude: 39.9042, longitude: 116.4074)
        XCTAssertEqual(gcj.latitude, 39.8992, accuracy: 0.001)
        XCTAssertEqual(gcj.longitude, 116.4107, accuracy: 0.001)
    }

    func testRoundTripWithinOneMeter() {
        let samples: [(Double, Double)] = [
            (39.9042, 116.4074),   // 北京
            (31.2304, 121.4737),   // 上海
            (23.1291, 113.2644),   // 广州
            (30.5728, 104.0668),   // 成都
            (29.6520, 91.1721),    // 拉萨
            (43.8256, 87.6168),    // 乌鲁木齐
        ]
        for (lat, lon) in samples {
            let gcj = CoordinateTransform.wgs84ToGCJ02(latitude: lat, longitude: lon)
            let back = CoordinateTransform.gcj02ToWGS84(latitude: gcj.latitude, longitude: gcj.longitude)
            let errorMeters = CLLocation(latitude: back.latitude, longitude: back.longitude)
                .distance(from: CLLocation(latitude: lat, longitude: lon))
            XCTAssertLessThan(errorMeters, 1.0, "\(lat),\(lon) 反解误差 \(errorMeters) 米")
        }
    }

    func testOutsideChinaPassesThrough() {
        // 东京与新加坡不在中国大陆包络框内，应原样返回
        let tokyo = CoordinateTransform.wgs84ToGCJ02(latitude: 35.6762, longitude: 139.6503)
        XCTAssertEqual(tokyo.latitude, 35.6762, accuracy: 1e-9)
        XCTAssertEqual(tokyo.longitude, 139.6503, accuracy: 1e-9)

        let singapore = CoordinateTransform.wgs84ToGCJ02(latitude: 1.3521, longitude: 103.8198)
        XCTAssertEqual(singapore.latitude, 1.3521, accuracy: 1e-9)
    }
}
