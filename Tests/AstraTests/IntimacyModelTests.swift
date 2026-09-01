import XCTest
@testable import Astra

final class IntimacyModelTests: XCTestCase {

    func testSixDimensionScorecardUsesWeightedOverall() {
        var scorecard = CompanionScorecard(
            looks: 8,
            body: 7,
            chemistry: 9,
            initiative: 6,
            desire: 10,
            afterglow: 8
        )
        XCTAssertEqual(scorecard.overallScore, 82)
        XCTAssertEqual(scorecard.completedCount, 6)
        XCTAssertEqual(scorecard.legacyStarRating, 4)

        let companion = Companion(name: "她", rating: 1, scorecard: scorecard)
        XCTAssertEqual(companion.rating, 4)

        scorecard.set(99, for: .looks)
        XCTAssertEqual(scorecard.looks, 10)
    }

    func testLegacyFiveStarRatingSeedsAllScoreDimensions() {
        let companion = Companion(name: "旧档案", rating: 4)
        XCTAssertEqual(companion.overallScore, 80)
        XCTAssertEqual(companion.scorecard.chemistry, 8)
        XCTAssertEqual(companion.scorecard.desire, 8)
    }

    func testExtremeImportedPaletteIndexDoesNotOverflow() {
        _ = Palette.avatarGradient(Int.min)
        _ = Palette.avatarGradient(Int.max)
    }

    func testExplicitBustSizeCombinesBandAndCup() throws {
        let companion = Companion(name: "她", bustBandCM: 75, bustSize: .d)
        XCTAssertEqual(companion.bustSizeText, "75D")

        let cupOnly = Companion(name: "她", bustSize: .c)
        XCTAssertEqual(cupOnly.bustSizeText, "C 杯")
        XCTAssertEqual(BustSize.k.label, "K 杯")

        let legacy = try JSONDecoder().decode(BustSize.self, from: Data(#""hPlus""#.utf8))
        XCTAssertEqual(legacy, .h)
    }

    func testScorecardClampsAndDecodesMissingDimensions() throws {
        let json = #"{"looks": 99, "desire": 8}"#.data(using: .utf8)!
        let scorecard = try JSONDecoder().decode(CompanionScorecard.self, from: json)

        XCTAssertEqual(scorecard.looks, 10)
        XCTAssertEqual(scorecard.desire, 8)
        XCTAssertEqual(scorecard.chemistry, 0)
        XCTAssertEqual(scorecard.completedCount, 2)
    }

    func testPausedAndEndedStagesDoNotTriggerCurrentRelationshipFlows() {
        XCTAssertTrue(RelationStage.new.isActive)
        XCTAssertTrue(RelationStage.chatting.isActive)
        XCTAssertTrue(RelationStage.flirting.isActive)
        XCTAssertTrue(RelationStage.prospect.isActive)
        XCTAssertTrue(RelationStage.casual.isActive)
        XCTAssertTrue(RelationStage.regular.isActive)
        XCTAssertFalse(RelationStage.paused.isActive)
        XCTAssertFalse(RelationStage.ended.isActive)
    }

    func testRecordableKindsOnlyExposeTheTwoOutcomes() {
        XCTAssertTrue(EncounterKind.intimacy.isIntimate)
        XCTAssertFalse(EncounterKind.intimacy.isMissed)
        XCTAssertTrue(EncounterKind.missed.isMissed)
        XCTAssertFalse(EncounterKind.missed.isIntimate)
        XCTAssertEqual(EncounterKind.allCases, [.intimacy, .missed])
        XCTAssertEqual(EncounterKind.recordableCases, [.intimacy, .missed])
    }

    func testMissedOutcomeCannotCarryIntimateOnlyFields() {
        let encounter = Encounter(
            companionID: UUID(),
            kind: .missed,
            physicalRating: 5,
            activities: [.vaginalPenetration],
            protectionStatus: .noProtection,
            safetyMeasures: [.externalCondom],
            safetyNote: "不应保留",
            followUpKinds: [.testing, .planMeet]
        )

        XCTAssertEqual(encounter.physicalRating, 0)
        XCTAssertTrue(encounter.activities.isEmpty)
        XCTAssertEqual(encounter.protectionStatus, .notApplicable)
        XCTAssertTrue(encounter.safetyMeasures.isEmpty)
        XCTAssertTrue(encounter.safetyNote.isEmpty)
        XCTAssertEqual(encounter.followUpKinds, [.planMeet])
    }

    func testProspectSitsBetweenFlirtingAndHookup() {
        XCTAssertEqual(RelationStage.prospect.label, "准炮友")
        XCTAssertEqual(RelationStage.casual.label, "炮友")
        XCTAssertEqual(RelationStage.regular.label, "固定炮友")
        XCTAssertGreaterThan(RelationStage.prospect.weight, RelationStage.flirting.weight)
        XCTAssertGreaterThan(RelationStage.casual.weight, RelationStage.prospect.weight)
        XCTAssertGreaterThan(RelationStage.regular.weight, RelationStage.casual.weight)
    }

    func testProtectionRecordingState() {
        XCTAssertFalse(ProtectionStatus.notRecorded.isRecorded)
        XCTAssertTrue(ProtectionStatus.protected.isRecorded)
        XCTAssertTrue(ProtectionStatus.partial.isRecorded)
        XCTAssertTrue(ProtectionStatus.noProtection.isRecorded)
        XCTAssertTrue(ProtectionStatus.notApplicable.isRecorded)
        XCTAssertFalse(ProtectionStatus.protected.hasBarrierGap)
        XCTAssertTrue(ProtectionStatus.partial.hasBarrierGap)
        XCTAssertTrue(ProtectionStatus.noProtection.hasBarrierGap)
    }

    func testBarrierMeasuresAreDistinguishedFromOtherSafetyFacts() {
        XCTAssertTrue(SafetyMeasure.externalCondom.isBarrier)
        XCTAssertTrue(SafetyMeasure.internalCondom.isBarrier)
        XCTAssertTrue(SafetyMeasure.oralBarrier.isBarrier)
        XCTAssertFalse(SafetyMeasure.prep.isBarrier)
        XCTAssertFalse(SafetyMeasure.contraception.isBarrier)
        XCTAssertFalse(SafetyMeasure.lubricant.isBarrier)
    }

    func testUnansweredExperienceDoesNotBecomeAnInventedScore() {
        let encounter = Encounter(companionID: UUID())
        XCTAssertNil(encounter.experienceRating)

        let partial = Encounter(companionID: UUID(), physicalRating: 4)
        XCTAssertEqual(partial.experienceRating, 4)

        let complete = Encounter(companionID: UUID(), physicalRating: 3, emotionalRating: 5)
        XCTAssertEqual(complete.experienceRating, 4)
    }

    func testExperienceRatingsAreClampedFromInitializersAndBackups() throws {
        let initialized = Encounter(
            companionID: UUID(),
            physicalRating: 99,
            emotionalRating: -4
        )
        XCTAssertEqual(initialized.physicalRating, 5)
        XCTAssertEqual(initialized.emotionalRating, 0)

        let companionID = UUID()
        let json = """
        {
          "companionID": "\(companionID.uuidString)",
          "kind": "intimacy",
          "physicalRating": 99,
          "emotionalRating": -4
        }
        """
        let decoded = try JSONDecoder().decode(Encounter.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.physicalRating, 5)
        XCTAssertEqual(decoded.emotionalRating, 0)
    }

    func testFollowUpIsPendingOnlyWhenExplicitlySelectedAndIncomplete() {
        var encounter = Encounter(companionID: UUID())
        XCTAssertFalse(encounter.hasPendingFollowUp)

        encounter.followUpKinds = [.testing, .message]
        XCTAssertTrue(encounter.hasPendingFollowUp)
        XCTAssertEqual(encounter.followUpSummary, "回个消息、去做检测")

        encounter.isFollowUpDone = true
        XCTAssertFalse(encounter.hasPendingFollowUp)
    }

    func testActivitySummaryUsesStableClinicalOrder() {
        let encounter = Encounter(
            companionID: UUID(),
            activities: [.toys, .kissing, .analReceptive, .oralGiving]
        )
        XCTAssertEqual(encounter.activitySummary, "亲亲、口 · 我给她、肛 · 我在下 等 4 项")
    }

    func testClimaxSummaryKeepsFinishDetailsSeparate() {
        let encounter = Encounter(
            companionID: UUID(),
            climaxDetails: [.facial, .creampie, .sheCame]
        )
        XCTAssertEqual(encounter.climaxSummary, "她高潮了、内射、颜射")
        XCTAssertTrue(encounter.activitySummary.isEmpty)
    }

    func testOnlyUncertainBoundaryStatesSuggestFollowUp() {
        XCTAssertFalse(BoundaryFeeling.notRecorded.needsFollowUp)
        XCTAssertFalse(BoundaryFeeling.comfortable.needsFollowUp)
        XCTAssertTrue(BoundaryFeeling.uncertain.needsFollowUp)
        XCTAssertTrue(BoundaryFeeling.concern.needsFollowUp)
    }

}
