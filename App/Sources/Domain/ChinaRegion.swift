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

    /// 全国概览视角
    static let overview = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.6, longitude: 105.5),
        span: MKCoordinateSpan(latitudeDelta: 38.0, longitudeDelta: 42.0)
    )

    /// 相机中心允许游走的范围——比包络框略大，避免边缘城市卡在屏幕角落无法居中。
    static let cameraCenterBounds = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.6, longitude: 105.5),
        span: MKCoordinateSpan(latitudeDelta: 56.0, longitudeDelta: 68.0)
    )

    /// 最近可以推到「街区」级，但本 App 只展示到市，所以下限给到 6km
    static let minimumCameraDistance: CLLocationDistance = 6_000
    /// 拉到最远刚好装下整个中国
    static let maximumCameraDistance: CLLocationDistance = 6_400_000

    static var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            centerCoordinateBounds: cameraCenterBounds,
            minimumDistance: minimumCameraDistance,
            maximumDistance: maximumCameraDistance
        )
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
