import XCTest
import UIKit
@testable import Astra

final class BackupServiceTests: XCTestCase {

    func testMediaStoreRejectsUnsafeImportedIDs() {
        XCTAssertTrue(MediaStore.isValidID(UUID().uuidString))
        XCTAssertTrue(MediaStore.isValidID("avatar-1_profile"))

        XCTAssertFalse(MediaStore.isValidID(""))
        XCTAssertFalse(MediaStore.isValidID("../outside"))
        XCTAssertFalse(MediaStore.isValidID("folder/photo"))
        XCTAssertFalse(MediaStore.isValidID("folder\\photo"))
        XCTAssertFalse(MediaStore.isValidID(String(repeating: "a", count: 129)))
        XCTAssertFalse(MediaStore.save(data: Data([0x01]), id: "../outside"))
        XCTAssertNil(MediaStore.data(id: "../outside"))
    }

    func testMergeStyleRestoreDoesNotOverwriteExistingMedia() {
        let mediaID = "restore-\(UUID().uuidString)"
        defer { MediaStore.delete(id: mediaID) }

        XCTAssertTrue(MediaStore.save(data: Data([0x01]), id: mediaID))
        XCTAssertTrue(MediaStore.restore([mediaID: Data([0x02])], overwriteExisting: false).isEmpty)
        XCTAssertEqual(MediaStore.data(id: mediaID), Data([0x01]))

        XCTAssertTrue(MediaStore.restore([mediaID: Data([0x03])]).isEmpty)
        XCTAssertEqual(MediaStore.data(id: mediaID), Data([0x03]))
    }

    func testMediaDirectoryIsEligibleForSystemICloudBackup() throws {
        MediaStore.enableSystemBackup()
        let values = try MediaStore.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertNotEqual(values.isExcludedFromBackup, true)
    }

    func testMediaEncodingUsesPixelLimitOnRetinaImages() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 1_000, height: 500),
            format: format
        ).image { context in
            UIColor.magenta.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_000, height: 500))
        }

        let data = try XCTUnwrap(MediaStore.jpegData(from: image, maxSide: 400))
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)

        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), 400)
    }

    func testEncodeDecodeRoundTrip() throws {
        let companion = Companion(
            name: "测试",
            cityID: "330100",
            stage: .casual,
            rating: 4,
            scorecard: CompanionScorecard(looks: 8, body: 9, chemistry: 10, initiative: 7, desire: 10, afterglow: 9),
            profilePhotoIDs: ["profile-1"],
            bustBandCM: 75,
            bustSize: .d,
            expectations: "偶尔见面",
            boundaries: "提前确认",
            safetyNotes: "只记已沟通的信息",
            tags: ["尊重", "守时"],
            notes: "备注内容"
        )
        let encounter = Encounter(
            companionID: companion.id,
            date: Date(timeIntervalSince1970: 1_750_000_000),
            kind: .intimacy,
            place: "湖滨银泰",
            cost: 328,
            physicalRating: 4,
            emotionalRating: 5,
            activities: [.kissing, .oralReceiving],
            boundaryFeeling: .comfortable,
            personalStates: [.clearheaded],
            protectionStatus: .protected,
            safetyMeasures: [.externalCondom, .lubricant],
            safetyNote: "已确认",
            meetAgainIntent: .yes,
            followUpKinds: [.testing],
            followUpDate: Date(timeIntervalSince1970: 1_750_086_400),
            followUpNote: "预约检测"
        )

        let data = try BackupService.encode(companions: [companion], encounters: [encounter])
        let decoded = try BackupService.decode(data)

        XCTAssertEqual(decoded.format, BackupService.formatIdentifier)
        XCTAssertEqual(decoded.version, BackupService.currentVersion)
        XCTAssertEqual(decoded.companions.count, 1)
        XCTAssertEqual(decoded.companions.first?.name, "测试")
        XCTAssertEqual(decoded.companions.first?.stage, .casual)
        XCTAssertEqual(decoded.companions.first?.overallScore, 90)
        XCTAssertEqual(decoded.companions.first?.profilePhotoIDs, ["profile-1"])
        XCTAssertEqual(decoded.companions.first?.bustSizeText, "75D")
        XCTAssertEqual(decoded.companions.first?.expectations, "偶尔见面")
        XCTAssertEqual(decoded.companions.first?.boundaries, "提前确认")
        XCTAssertEqual(decoded.companions.first?.tags, ["尊重", "守时"])
        XCTAssertEqual(decoded.encounters.count, 1)

        let decodedEncounter = try XCTUnwrap(decoded.encounters.first)
        XCTAssertEqual(decodedEncounter.cost, 328)
        XCTAssertEqual(decodedEncounter.protectionStatus, .protected)
        XCTAssertEqual(decodedEncounter.activities, [.kissing, .oralReceiving])
        XCTAssertEqual(decodedEncounter.safetyMeasures, [.externalCondom, .lubricant])
        XCTAssertEqual(decodedEncounter.boundaryFeeling, .comfortable)
        XCTAssertEqual(decodedEncounter.physicalRating, 4)
        XCTAssertEqual(decodedEncounter.emotionalRating, 5)
        XCTAssertEqual(decodedEncounter.followUpKinds, [.testing])
        XCTAssertEqual(decodedEncounter.safetyNote, "已确认")
        XCTAssertEqual(
            decodedEncounter.date.timeIntervalSince1970,
            encounter.date.timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testRejectsForeignJSON() {
        let garbage = #"{"hello": "world"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try BackupService.decode(garbage)) { error in
            guard case BackupError.notAnAstraBackup = error else {
                return XCTFail("预期 notAnAstraBackup，实际 \(error)")
            }
        }
    }

    func testConversationDetailsRoundTrip() throws {
        let companion = Companion(name: "她", cityID: "310000", stage: .flirting)
        let encounter = Encounter(
            companionID: companion.id,
            kind: .flirting,
            emotionalRating: 4,
            chatProgress: .discussingMeet,
            explicitContentComfort: .limited,
            acceptedExplicitMedia: [.text],
            conversationTopics: [.chatPace, .boundaries, .meetingPlan],
            digitalBoundaries: [.noScreenshots, .noForwarding],
            conversationSafetyFlags: [.identityNotConfirmed, .suspiciousLink],
            meetAgainIntent: .yes,
            followUpKinds: [.planMeet],
            followUpNote: "等她确认周末时间"
        )

        let data = try BackupService.encode(companions: [companion], encounters: [encounter])
        let decoded = try BackupService.decode(data)
        let record = try XCTUnwrap(decoded.encounters.first)

        XCTAssertEqual(record.kind, .flirting)
        XCTAssertEqual(record.chatProgress, .discussingMeet)
        XCTAssertEqual(record.explicitContentComfort, .limited)
        XCTAssertEqual(record.acceptedExplicitMedia, [.text])
        XCTAssertEqual(record.conversationTopics, [.chatPace, .boundaries, .meetingPlan])
        XCTAssertEqual(record.digitalBoundaries, [.noScreenshots, .noForwarding])
        XCTAssertEqual(record.conversationSafetyFlags, [.identityNotConfirmed, .suspiciousLink])
        XCTAssertTrue(record.hasConversationSafetyConcern)
        XCTAssertEqual(record.followUpKinds, [.planMeet])
    }

    func testCompanionDecodesWithMissingOptionalFields() throws {
        // 局部字段缺失时仍能给出稳定默认值。
        let json = """
        {"id": "\(UUID().uuidString)", "name": "旧档案", "cityID": "310000"}
        """
        let companion = try JSONDecoder().decode(Companion.self, from: Data(json.utf8))
        XCTAssertEqual(companion.name, "旧档案")
        XCTAssertEqual(companion.stage, .chatting)
        XCTAssertTrue(companion.tags.isEmpty)
        XCTAssertFalse(companion.isArchived)
        XCTAssertNil(companion.birthdayMonth)
        XCTAssertNil(companion.photoID)
        XCTAssertTrue(companion.profilePhotoIDs.isEmpty)
        XCTAssertTrue(companion.albumPhotoIDs.isEmpty)
        XCTAssertEqual(companion.overallScore, 60)
        XCTAssertNil(companion.bustSizeText)
    }

    func testEncounterDecodesMissingPhotoIDs() throws {
        let id = UUID()
        let json = """
        {"id": "\(UUID().uuidString)", "companionID": "\(id.uuidString)", "kind": "intimacy"}
        """
        let encounter = try JSONDecoder().decode(Encounter.self, from: Data(json.utf8))
        XCTAssertTrue(encounter.photoIDs.isEmpty)
        XCTAssertTrue(encounter.climaxDetails.isEmpty)
        XCTAssertEqual(encounter.kind, .intimacy)
    }

    func testMediaRoundTripInBackup() throws {
        let companion = Companion(
            name: "她",
            photoID: "avatar-1",
            profilePhotoIDs: ["profile-1"],
            albumPhotoIDs: ["album-1"]
        )
        let encounter = Encounter(
            companionID: companion.id,
            kind: .intimacy,
            climaxDetails: [.creampie],
            photoIDs: ["shot-1"]
        )
        let media = [
            "avatar-1": Data([0xFF, 0xD8, 0xFF, 0xD9]),
            "profile-1": Data([0x03, 0x04]),
            "album-1": Data([0x01, 0x02]),
            "shot-1": Data([0x00, 0x01, 0x02]),
        ]

        let data = try BackupService.encode(companions: [companion], encounters: [encounter], media: media)
        let decoded = try BackupService.decode(data)

        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.companions.first?.photoID, "avatar-1")
        XCTAssertEqual(decoded.companions.first?.profilePhotoIDs, ["profile-1"])
        XCTAssertEqual(decoded.companions.first?.albumPhotoIDs, ["album-1"])
        XCTAssertEqual(decoded.encounters.first?.photoIDs, ["shot-1"])
        XCTAssertEqual(decoded.encounters.first?.climaxDetails, [.creampie])
        XCTAssertEqual(decoded.media["avatar-1"], media["avatar-1"])
        XCTAssertEqual(decoded.media["profile-1"], media["profile-1"])
        XCTAssertEqual(decoded.media["shot-1"], media["shot-1"])
        XCTAssertEqual(decoded.media["album-1"], media["album-1"])
    }

    func testV1BackupWithoutMediaStillDecodes() throws {
        let json = """
        {
          "format": "astra.backup",
          "version": 1,
          "exportedAt": "2026-08-01T00:00:00Z",
          "companions": [],
          "encounters": []
        }
        """
        let payload = try BackupService.decode(Data(json.utf8))
        XCTAssertEqual(payload.version, 1)
        XCTAssertTrue(payload.media.isEmpty)
        XCTAssertTrue(payload.companions.isEmpty)
    }

    func testRejectsDuplicateRecordIDsBeforeImport() throws {
        let companionID = UUID()
        let first = Companion(id: companionID, name: "甲")
        let second = Companion(id: companionID, name: "乙")
        let duplicateCompanions = try BackupService.encode(
            companions: [first, second],
            encounters: []
        )
        XCTAssertThrowsError(try BackupService.decode(duplicateCompanions)) { error in
            guard case BackupError.invalidContents = error else {
                return XCTFail("预期 invalidContents，实际 \(error)")
            }
        }

        let encounterID = UUID()
        let one = Encounter(id: encounterID, companionID: companionID)
        let two = Encounter(id: encounterID, companionID: companionID)
        let duplicateEncounters = try BackupService.encode(
            companions: [first],
            encounters: [one, two]
        )
        XCTAssertThrowsError(try BackupService.decode(duplicateEncounters))
    }

    func testRejectsOrphanRecordsAndUnsafeMediaReferences() throws {
        let companion = Companion(name: "她")
        let orphan = Encounter(companionID: UUID())
        let orphanData = try BackupService.encode(companions: [companion], encounters: [orphan])
        XCTAssertThrowsError(try BackupService.decode(orphanData))

        let unsafe = Companion(name: "她", photoID: "../outside")
        let unsafeData = try BackupService.encode(
            companions: [unsafe],
            encounters: [],
            media: ["../outside": Data([0x01])]
        )
        XCTAssertThrowsError(try BackupService.decode(unsafeData))
    }
}
