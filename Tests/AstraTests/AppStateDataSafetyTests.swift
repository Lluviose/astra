import XCTest
import UIKit
@testable import Astra

final class AppStateDataSafetyTests: XCTestCase {

    @MainActor
    func testCorruptMetadataDoesNotGarbageCollectUserMedia() {
        let (defaults, suiteName) = makeDefaults()
        let mediaID = "corrupt-metadata-\(UUID().uuidString)"
        XCTAssertTrue(MediaStore.save(data: Data([0xFF, 0xD8, 0xFF, 0xD9]), id: mediaID))

        defer {
            MediaStore.delete(id: mediaID)
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(Data("not-json".utf8), forKey: LocalStore.Key.companions.rawValue)
        let store = LocalStore(defaults: defaults)
        store.save([Encounter](), for: .encounters)

        _ = AppState(store: store, catalog: .shared)

        XCTAssertNotNil(MediaStore.data(id: mediaID))
    }

    @MainActor
    func testRemovingOneReferenceKeepsMediaUsedByAnotherProfile() {
        let (defaults, suiteName) = makeDefaults()
        let mediaID = "shared-reference-\(UUID().uuidString)"
        XCTAssertTrue(MediaStore.save(data: Data([0xFF, 0xD8, 0xFF, 0xD9]), id: mediaID))

        defer {
            MediaStore.delete(id: mediaID)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let first = Companion(name: "甲", albumPhotoIDs: [mediaID])
        let second = Companion(name: "乙", profilePhotoIDs: [mediaID])
        let store = LocalStore(defaults: defaults)
        store.save([first, second], for: .companions)
        store.save([Encounter](), for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        app.removeAlbumPhoto(mediaID, from: first.id)

        XCTAssertEqual(app.companion(id: first.id)?.albumPhotoIDs, [])
        XCTAssertEqual(app.companion(id: second.id)?.profilePhotoIDs, [mediaID])
        XCTAssertNotNil(MediaStore.data(id: mediaID))
    }

    @MainActor
    func testOnlyTrulyUnreferencedCandidatesAreDeleted() {
        let avatarID = "avatar"
        let profileID = "profile"
        let dossierID = "dossier"
        let albumID = "album"
        let encounterID = "encounter"
        let orphanID = "orphan"
        let companion = Companion(
            name: "她",
            photoID: avatarID,
            profilePhotoIDs: [profileID],
            dossierPhotoIDs: [dossierID],
            albumPhotoIDs: [albumID]
        )
        let encounter = Encounter(companionID: companion.id, photoIDs: [encounterID])

        let result = AppState.unreferencedMediaIDs(
            among: [avatarID, profileID, dossierID, albumID, encounterID, orphanID],
            companions: [companion],
            encounters: [encounter]
        )

        XCTAssertEqual(result, [orphanID])
    }

    @MainActor
    func testProfileDossierAndAlbumPhotosHaveNoApplicationCountLimit() throws {
        let (defaults, suiteName) = makeDefaults()
        let sourceData = try XCTUnwrap(
            UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
                UIColor.systemPurple.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            }.pngData()
        )
        let profileIDs = (0..<9).map { "unlimited-profile-\($0)-\(UUID().uuidString)" }
        let dossierIDs = (0..<12).map { "unlimited-dossier-\($0)-\(UUID().uuidString)" }
        let albumIDs = (0..<25).map { "unlimited-album-\($0)-\(UUID().uuidString)" }
        let allIDs = profileIDs + dossierIDs + albumIDs
        for id in allIDs {
            XCTAssertEqual(MediaStore.saveOriginal(data: sourceData, id: id), id)
        }

        defer {
            MediaStore.delete(ids: allIDs)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let companion = Companion(name: "她")
        let store = LocalStore(defaults: defaults)
        store.save([companion], for: .companions)
        store.save([Encounter](), for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        app.addProfilePhotoIDs(profileIDs, to: companion.id)
        app.addDossierPhotoIDs(dossierIDs, to: companion.id)
        app.addAlbumPhotoIDs(albumIDs, to: companion.id)

        XCTAssertEqual(app.companion(id: companion.id)?.profilePhotoIDs, profileIDs)
        XCTAssertEqual(app.companion(id: companion.id)?.dossierPhotoIDs, dossierIDs)
        XCTAssertEqual(app.companion(id: companion.id)?.albumPhotoIDs, albumIDs)
    }

    @MainActor
    func testRemovingDossierPhotoDeletesItsUnsharedMedia() {
        let (defaults, suiteName) = makeDefaults()
        let mediaID = "remove-dossier-\(UUID().uuidString)"
        XCTAssertTrue(MediaStore.save(data: Data([0xFF, 0xD8, 0xFF, 0xD9]), id: mediaID))

        defer {
            MediaStore.delete(id: mediaID)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let companion = Companion(name: "她", dossierPhotoIDs: [mediaID])
        let store = LocalStore(defaults: defaults)
        store.save([companion], for: .companions)
        store.save([Encounter](), for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        app.removeDossierPhoto(mediaID, from: companion.id)

        XCTAssertTrue(app.companion(id: companion.id)?.dossierPhotoIDs.isEmpty == true)
        XCTAssertNil(MediaStore.data(id: mediaID))
    }

    @MainActor
    func testAppLockStartsBehindPrivacyCurtainUntilConfigured() {
        let lock = AppLock()
        XCTAssertFalse(lock.isConfigured)

        lock.configure(enabled: false)

        XCTAssertTrue(lock.isConfigured)
        XCTAssertFalse(lock.isLocked)
    }

    @MainActor
    func testTimelineWithNegativeLimitReturnsEmptyInsteadOfTrapping() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let companion = Companion(name: "她")
        let store = LocalStore(defaults: defaults)
        store.save([companion], for: .companions)
        store.save([Encounter(companionID: companion.id)], for: .encounters)
        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        XCTAssertTrue(app.timeline(limit: -1).isEmpty)
    }

    @MainActor
    func testMapBucketsUseActualRecordCityAndBothOutcomes() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let companion = Companion(name: "她", cityID: "310000")
        let hookup = Encounter(companionID: companion.id, kind: .intimacy, cityID: "110000")
        let missed = Encounter(companionID: companion.id, kind: .missed, cityID: "310000")
        let store = LocalStore(defaults: defaults)
        store.save([companion], for: .companions)
        store.save([hookup, missed], for: .encounters)

        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)
        let beijing = try XCTUnwrap(app.buckets.first { $0.id == "110000" })
        let shanghai = try XCTUnwrap(app.buckets.first { $0.id == "310000" })

        XCTAssertEqual(beijing.hookupCount, 1)
        XCTAssertEqual(beijing.missedCount, 0)
        XCTAssertEqual(beijing.companions.map(\.id), [companion.id])
        XCTAssertEqual(shanghai.hookupCount, 0)
        XCTAssertEqual(shanghai.missedCount, 1)
        XCTAssertEqual(app.stats.cityCount, 2)
        XCTAssertEqual(app.stats.totalIntimacyCount, 1)
        XCTAssertEqual(app.stats.missedCount, 1)
    }

    @MainActor
    func testCountryLevelLocationsFlowThroughBucketsStatsAndRoute() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let companion = Companion(name: "她", cityID: "country:US")
        let encounters = [
            Encounter(
                companionID: companion.id,
                date: Date(timeIntervalSince1970: 100),
                kind: .intimacy,
                cityID: "country:US"
            ),
            Encounter(
                companionID: companion.id,
                date: Date(timeIntervalSince1970: 200),
                kind: .intimacy,
                cityID: "country:JP"
            ),
        ]
        let store = LocalStore(defaults: defaults)
        store.save([companion], for: .companions)
        store.save(encounters, for: .encounters)

        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        XCTAssertEqual(app.locationName(for: companion), "美国")
        XCTAssertTrue(app.hasCountryLocations)
        XCTAssertEqual(app.stats.cityCount, 2)
        XCTAssertEqual(app.conquestLocationCount, 2)
        XCTAssertEqual(app.conquestLocationPath().map(\.id), ["country:US", "country:JP"])
        XCTAssertEqual(app.buckets.first { $0.id == "country:JP" }?.city.locationLevelLabel, "国家")
    }

    @MainActor
    func testHaremCollectionAndConquestRouteOnlyUseHookups() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = Companion(
            name: "甲",
            cityID: "310000",
            profilePhotoIDs: ["first-profile"],
            dossierPhotoIDs: ["first-dossier"],
            albumPhotoIDs: ["first-private"]
        )
        let second = Companion(
            name: "乙",
            cityID: "110000",
            albumPhotoIDs: ["second-private"]
        )
        let missedOnly = Companion(name: "丙", cityID: "440100")
        let encounters = [
            Encounter(
                companionID: first.id,
                date: Date(timeIntervalSince1970: 100),
                kind: .intimacy,
                cityID: "310000",
                photoIDs: ["first-encounter"]
            ),
            Encounter(
                companionID: second.id,
                date: Date(timeIntervalSince1970: 200),
                kind: .intimacy,
                cityID: "110000"
            ),
            Encounter(
                companionID: first.id,
                date: Date(timeIntervalSince1970: 300),
                kind: .intimacy,
                cityID: "110000"
            ),
            Encounter(
                companionID: second.id,
                date: Date(timeIntervalSince1970: 400),
                kind: .intimacy,
                cityID: "110000"
            ),
            Encounter(
                companionID: missedOnly.id,
                date: Date(timeIntervalSince1970: 500),
                kind: .missed,
                cityID: "440100"
            ),
        ]
        let store = LocalStore(defaults: defaults)
        store.save([first, second, missedOnly], for: .companions)
        store.save(encounters, for: .encounters)

        let app = AppState(store: store, catalog: .shared, performsMediaMaintenance: false)

        XCTAssertEqual(app.conqueredCompanions.map(\.id), [second.id, first.id])
        XCTAssertEqual(app.privateCollectionCount, 3)
        XCTAssertEqual(app.conquestLocationCount, 2)
        XCTAssertEqual(app.conquestLocationPath().map(\.id), ["310000", "110000"])
        XCTAssertEqual(app.topConquestBucket?.id, "110000")
        XCTAssertEqual(app.topConquestBucket?.hookupCount, 3)
        XCTAssertEqual(app.topConquestBucket?.hookupCompanionCount, 2)
        XCTAssertEqual(app.topConquestBucket?.hookupRate, 1)
        XCTAssertEqual(app.lastHookup(for: second.id)?.date, Date(timeIntervalSince1970: 400))
        XCTAssertFalse(app.conqueredCompanions.contains { $0.id == missedOnly.id })
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "AstraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
