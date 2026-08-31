import CoreLocation
import Foundation
import MapKit

/// 把可视区域与数据都锁死在中国境内。
enum ChinaRegion {

    /// 经纬度包络框（含港澳台及南海诸岛）
    static let minLatitude = 3.5
    static let maxLatitude = 53.8
    static let minLongitude = 73.4
    static let maxLongitude = 135.2

    /// 全国概览：经度跨度要盖住新疆到黑龙江，竖屏上刚好看清整张中国。
    static let overview = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.0, longitude: 104.0),
        span: MKCoordinateSpan(latitudeDelta: 42.0, longitudeDelta: 72.0)
    )

    /// 相机中心允许游走的范围——比包络框略大，避免边缘城市卡在屏幕角落无法居中。
    static let cameraCenterBounds = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.0, longitude: 104.0),
        span: MKCoordinateSpan(latitudeDelta: 62.0, longitudeDelta: 82.0)
    )

    /// 最近可以推到「街区」级，但本 App 只展示到市，所以下限给到 6km
    static let minimumCameraDistance: CLLocationDistance = 6_000
    /// 竖屏要一眼看全中国（含新疆、黑龙江、海南），需要约 1.8 万公里相机高度。
    static let maximumCameraDistance: CLLocationDistance = 18_000_000

    /// 交给 SwiftUI Map 的原生边界，拖动手势由 MapKit 自己钳制，不会每帧回写相机。
    static let cameraBounds = MapCameraBounds(
        centerCoordinateBounds: cameraCenterBounds,
        minimumDistance: minimumCameraDistance,
        maximumDistance: maximumCameraDistance
    )

    /// 把相机中心钳制到包络框内（必要时向外留一点余量）
    static func clamp(center: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: min(max(center.latitude, minLatitude), maxLatitude),
            longitude: min(max(center.longitude, minLongitude), maxLongitude)
        )
    }

    /// 把相机高度钳制到合理区间
    static func clamp(distance: CLLocationDistance) -> CLLocationDistance {
        min(max(distance, minimumCameraDistance), maximumCameraDistance)
    }

    static func contains(latitude: Double, longitude: Double) -> Bool {
        latitude >= minLatitude && latitude <= maxLatitude
            && longitude >= minLongitude && longitude <= maxLongitude
    }

    static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        contains(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// 以某座城市为中心的聚焦视角
    static func focus(on coordinate: CLLocationCoordinate2D, spanDegrees: Double = 1.6) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )
    }
}
