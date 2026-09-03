import CoreLocation
import Foundation
import MapKit
import SwiftUI

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

/// 当数据中出现境外国家时使用的全球相机边界。
/// 不取代 `ChinaRegion`：只有中国城市时，地图仍保持原有的中国范围与缩放体验。
enum WorldRegion {
    /// 一键缩小的视野计划。单个半球能装下时直接框住全部地点，
    /// 跨度过大时由 `tourStops` 提供需要依次转到的半球中心。
    struct OverviewPlan {
        let region: MKCoordinateRegion
        let fitsInSingleView: Bool
        let tourStops: [CLLocationCoordinate2D]
    }

    static let overview = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 18, longitude: 15),
        span: MKCoordinateSpan(latitudeDelta: 145, longitudeDelta: 330)
    )

    static let cameraCenterBounds = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 165, longitudeDelta: 358)
    )

    static let minimumCameraDistance: CLLocationDistance = ChinaRegion.minimumCameraDistance
    static let maximumCameraDistance: CLLocationDistance = 60_000_000
    /// 在这个高度上一次可见约一个半球，适合用于跨洲巡视。
    static let globeCameraDistance: CLLocationDistance = 38_000_000

    static let cameraBounds = MapCameraBounds(
        centerCoordinateBounds: cameraCenterBounds,
        minimumDistance: minimumCameraDistance,
        maximumDistance: maximumCameraDistance
    )

    /// 按真实地点计算最小视野，而不是把全球视角固定在非洲。
    /// 经度使用“最大空白弧的补集”，所以日界线两侧的点也会被就近框住。
    static func overviewPlan(for coordinates: [CLLocationCoordinate2D]) -> OverviewPlan {
        let validCoordinates = coordinates.filter {
            $0.latitude.isFinite && $0.longitude.isFinite
                && (-90.0 ... 90.0).contains($0.latitude)
        }
        guard !validCoordinates.isEmpty else {
            return OverviewPlan(region: overview, fitsInSingleView: true, tourStops: [])
        }

        let latitudes = validCoordinates.map(\.latitude)
        let minimumLatitude = latitudes.min() ?? 0
        let maximumLatitude = latitudes.max() ?? 0
        let latitudeSpan = maximumLatitude - minimumLatitude
        let longitudeArc = minimumLongitudeArc(validCoordinates.map(\.longitude))

        // 留出气泡标记和顶部面板的空间；附近只有一个国家时也不会贴得过近。
        let paddedLatitudeSpan = max(22, latitudeSpan + max(8, latitudeSpan * 0.28))
        let paddedLongitudeSpan = max(22, longitudeArc.span + max(10, longitudeArc.span * 0.24))

        // 地球表面可见范围要小于 180°；再留一圈边缘，避免标记落在地平线上。
        let fitsInSingleView = longitudeArc.span <= 140 && latitudeSpan <= 100
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: min(max((minimumLatitude + maximumLatitude) / 2, -80), 80),
                longitude: normalizedLongitude(longitudeArc.center)
            ),
            span: MKCoordinateSpan(
                latitudeDelta: min(paddedLatitudeSpan, fitsInSingleView ? 145 : 165),
                longitudeDelta: min(paddedLongitudeSpan, fitsInSingleView ? 170 : 350)
            )
        )

        return OverviewPlan(
            region: region,
            fitsInSingleView: fitsInSingleView,
            tourStops: fitsInSingleView ? [] : makeTourStops(validCoordinates, arc: longitudeArc)
        )
    }

    static func globeCamera(center: CLLocationCoordinate2D) -> MapCamera {
        MapCamera(
            centerCoordinate: center,
            distance: globeCameraDistance,
            heading: 0,
            pitch: 0
        )
    }

    // MARK: - 全球视野计算

    private struct LongitudeArc {
        let start: Double
        let span: Double
        let center: Double
    }

    private struct TourPoint {
        let coordinate: CLLocationCoordinate2D
        let unwrappedLongitude: Double
    }

    /// 找到包住所有经度的最短圆弧，避免 `170°E / 170°W` 被误算成 340°。
    private static func minimumLongitudeArc(_ longitudes: [Double]) -> LongitudeArc {
        let sorted = longitudes.map(longitude360).sorted()
        guard let first = sorted.first else {
            return LongitudeArc(start: 0, span: 0, center: 0)
        }

        var largestGap = -Double.infinity
        var arcStart = first
        for index in sorted.indices {
            let nextIndex = sorted.index(after: index)
            let next = nextIndex == sorted.endIndex ? sorted[0] + 360 : sorted[nextIndex]
            let gap = next - sorted[index]
            if gap > largestGap {
                largestGap = gap
                arcStart = nextIndex == sorted.endIndex ? sorted[0] : sorted[nextIndex]
            }
        }

        let span = max(0, 360 - largestGap)
        return LongitudeArc(start: arcStart, span: span, center: arcStart + span / 2)
    }

    /// 把跨度过大的地点分成若干个半球可见的站点。
    /// 最多只需少量站点，不会按每个城市停顿而拖长动画。
    private static func makeTourStops(
        _ coordinates: [CLLocationCoordinate2D],
        arc: LongitudeArc
    ) -> [CLLocationCoordinate2D] {
        let points = coordinates
            .map { coordinate -> TourPoint in
                var longitude = longitude360(coordinate.longitude)
                if longitude < arc.start { longitude += 360 }
                return TourPoint(coordinate: coordinate, unwrappedLongitude: longitude)
            }
            .sorted {
                if $0.unwrappedLongitude != $1.unwrappedLongitude {
                    return $0.unwrappedLongitude < $1.unwrappedLongitude
                }
                return $0.coordinate.latitude < $1.coordinate.latitude
            }

        var longitudeGroups: [[TourPoint]] = []
        var currentGroup: [TourPoint] = []
        var groupStart = 0.0
        for point in points {
            if currentGroup.isEmpty {
                currentGroup = [point]
                groupStart = point.unwrappedLongitude
            } else if point.unwrappedLongitude - groupStart <= 140 {
                currentGroup.append(point)
            } else {
                longitudeGroups.append(currentGroup)
                currentGroup = [point]
                groupStart = point.unwrappedLongitude
            }
        }
        if !currentGroup.isEmpty { longitudeGroups.append(currentGroup) }

        var stops: [CLLocationCoordinate2D] = []
        for longitudeGroup in longitudeGroups {
            let latitudeSorted = longitudeGroup.sorted { $0.coordinate.latitude < $1.coordinate.latitude }
            var latitudeGroup: [TourPoint] = []
            var latitudeStart = 0.0
            for point in latitudeSorted {
                if latitudeGroup.isEmpty {
                    latitudeGroup = [point]
                    latitudeStart = point.coordinate.latitude
                } else if point.coordinate.latitude - latitudeStart <= 100 {
                    latitudeGroup.append(point)
                } else {
                    stops.append(tourCenter(for: latitudeGroup))
                    latitudeGroup = [point]
                    latitudeStart = point.coordinate.latitude
                }
            }
            if !latitudeGroup.isEmpty { stops.append(tourCenter(for: latitudeGroup)) }
        }
        return stops
    }

    private static func tourCenter(for points: [TourPoint]) -> CLLocationCoordinate2D {
        let latitudes = points.map { $0.coordinate.latitude }
        let longitudes = points.map(\.unwrappedLongitude)
        let latitude = ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2
        let longitude = ((longitudes.min() ?? 0) + (longitudes.max() ?? 0)) / 2
        return CLLocationCoordinate2D(
            latitude: min(max(latitude, -65), 65),
            longitude: normalizedLongitude(longitude)
        )
    }

    private static func longitude360(_ longitude: Double) -> Double {
        let remainder = longitude.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private static func normalizedLongitude(_ longitude: Double) -> Double {
        let normalized = longitude360(longitude + 180) - 180
        // `cameraCenterBounds` 在日界线两侧各留 1°，避免精确的 ±180° 被边界回弹。
        return min(max(normalized, -179), 179)
    }
}
