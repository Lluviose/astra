import CoreLocation
import MapKit
import SwiftUI
import XCTest
@testable import Astra

final class ChinaRegionTests: XCTestCase {

    func testOverviewSpanCoversChinaEastWest() {
        // 新疆西缘约 73.5°E，黑龙江东缘约 135°E，跨度约 62°。
        XCTAssertGreaterThanOrEqual(ChinaRegion.overview.span.longitudeDelta, 68)
        XCTAssertGreaterThanOrEqual(ChinaRegion.maximumCameraDistance, 12_000_000)
        XCTAssertLessThan(ChinaRegion.minimumCameraDistance, 20_000)
    }

    func testCameraCenterAllowsEdgeCitiesToSitInTheMiddle() {
        XCTAssertGreaterThan(ChinaRegion.cameraCenterBounds.span.longitudeDelta, 70)
        XCTAssertGreaterThan(ChinaRegion.cameraCenterBounds.span.latitudeDelta, 50)
        _ = ChinaRegion.cameraBounds
    }

    func testEdgeCitiesAreInsideEnvelope() {
        let samples: [(String, Double, Double)] = [
            ("乌鲁木齐", 43.8256, 87.6168),
            ("哈尔滨", 45.8038, 126.5350),
            ("三亚", 18.2528, 109.5119),
            ("漠河近似", 52.97, 122.54),
            ("喀什", 39.47, 75.99),
        ]
        for (name, lat, lon) in samples {
            XCTAssertTrue(ChinaRegion.contains(latitude: lat, longitude: lon), name)
            let clamped = ChinaRegion.clamp(center: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            XCTAssertEqual(clamped.latitude, lat, accuracy: 0.0001, name)
            XCTAssertEqual(clamped.longitude, lon, accuracy: 0.0001, name)
        }
    }

    func testWorldBoundsCanFrameInternationalCountryMarkers() {
        XCTAssertGreaterThanOrEqual(WorldRegion.overview.span.longitudeDelta, 300)
        XCTAssertGreaterThan(WorldRegion.maximumCameraDistance, ChinaRegion.maximumCameraDistance)
        XCTAssertGreaterThanOrEqual(WorldRegion.cameraCenterBounds.span.latitudeDelta, 160)
        _ = WorldRegion.cameraBounds
    }

    func testWorldOverviewFramesChinaAndThailandInsteadOfAfrica() {
        let plan = WorldRegion.overviewPlan(for: [
            CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            CLLocationCoordinate2D(latitude: 15.87, longitude: 100.9925),
        ])

        XCTAssertTrue(plan.fitsInSingleView)
        XCTAssertTrue(plan.tourStops.isEmpty)
        XCTAssertEqual(plan.region.center.latitude, 27.8871, accuracy: 0.001)
        XCTAssertEqual(plan.region.center.longitude, 108.69995, accuracy: 0.001)
        XCTAssertLessThan(plan.region.span.longitudeDelta, 40)
        XCTAssertLessThan(plan.region.span.latitudeDelta, 40)
    }

    func testWorldOverviewUsesShortestArcAcrossDateLine() {
        let plan = WorldRegion.overviewPlan(for: [
            CLLocationCoordinate2D(latitude: -17.7, longitude: 178.1),
            CLLocationCoordinate2D(latitude: -13.8, longitude: -172.1),
        ])

        XCTAssertTrue(plan.fitsInSingleView)
        XCTAssertLessThan(plan.region.span.longitudeDelta, 25)
        XCTAssertGreaterThan(abs(plan.region.center.longitude), 170)
    }

    func testWorldOverviewBuildsTourForLocationsBeyondOneHemisphere() {
        let plan = WorldRegion.overviewPlan(for: [
            CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        ])

        XCTAssertFalse(plan.fitsInSingleView)
        XCTAssertEqual(plan.tourStops.count, 2)
        XCTAssertEqual(WorldRegion.globeCameraDistance, 38_000_000)
    }
}
