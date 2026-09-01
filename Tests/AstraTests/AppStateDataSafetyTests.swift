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
        let albumID = "album"
        let encounterID = "encounter"
        let orphanID = "orphan"
        let companion = Companion(
            name: "她",
            photoID: avatarID,
            profilePhotoIDs: [profileID],
            albumPhotoIDs: [albumID]
        )
        let encounter = Encounter(companionID: companion.id, photoIDs: [encounterID])

        let result = AppState.unreferencedMediaIDs(
            among: [avatarID, profileID, albumID, encounterID, orphanID],
            companions: [companion],
            encounters: [encounter]
        )

        XCTAssertEqual(result, [orphanID])
    }

    @MainActor
    func testProfileAndAlbumPhotosHaveNoApplicationCountLimit() throws {
        let (defaults, suiteName) = makeDefaults()
        let sourceData = try XCTUnwrap(
            UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
                UIColor.systemPurple.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            }.pngData()
        )
        let profileIDs = (0..<9).map { "unlimited-profile-\($0)-\(UUID().uuidString)" }
        let albumIDs = (0..<25).map { "unlimited-album-\($0)-\(UUID().uuidString)" }
        let allIDs = profileIDs + albumIDs
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
        app.addAlbumPhotoIDs(albumIDs, to: companion.id)

        XCTAssertEqual(app.companion(id: companion.id)?.profilePhotoIDs, profileIDs)
        XCTAssertEqual(app.companion(id: companion.id)?.albumPhotoIDs, albumIDs)
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

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "AstraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
