import XCTest
@testable import Astra

final class IntimacyModelTests: XCTestCase {

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

    func testOnlyIntimateKindsAskForProtectionDetails() {
        XCTAssertTrue(EncounterKind.intimacy.isIntimate)
        XCTAssertTrue(EncounterKind.overnight.isIntimate)
        XCTAssertFalse(EncounterKind.meet.isIntimate)
        XCTAssertFalse(EncounterKind.flirting.isIntimate)
        XCTAssertFalse(EncounterKind.chat.isIntimate)
        XCTAssertTrue(EncounterKind.flirting.isConversation)
        XCTAssertTrue(EncounterKind.chat.isConversation)
        XCTAssertFalse(EncounterKind.intimacy.isConversation)
        XCTAssertFalse(EncounterKind.recordableCases.contains(.flirting))
        XCTAssertTrue(EncounterKind.recordableCases.contains(.chat))
        XCTAssertTrue(EncounterKind.recordableCases.contains(.intimacy))
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

    func testChatSummaryOnlyContainsExplicitlyRecordedFacts() {
        var encounter = Encounter(companionID: UUID(), kind: .flirting)
        XCTAssertTrue(encounter.conversationSummary.isEmpty)

        encounter.chatProgress = .discussingMeet
        encounter.explicitContentComfort = .limited
        XCTAssertEqual(encounter.conversationSummary, "在约见面 · 露骨内容：有范围")
    }

    func testSlowDownAndDeclineShouldNotBeEscalated() {
        XCTAssertTrue(ExplicitContentComfort.notRecorded.shouldNotEscalate)
        XCTAssertFalse(ExplicitContentComfort.explicitlyOkay.shouldNotEscalate)
        XCTAssertTrue(ExplicitContentComfort.wantsSlower.shouldNotEscalate)
        XCTAssertTrue(ExplicitContentComfort.declined.shouldNotEscalate)
    }

    func testExplicitMediaSummaryKeepsConsentSpecific() {
        let encounter = Encounter(
            companionID: UUID(),
            kind: .flirting,
            explicitContentComfort: .limited,
            acceptedExplicitMedia: [.videoCall, .text]
        )
        XCTAssertEqual(encounter.acceptedExplicitMediaSummary, "黄段子 / 露骨文字、视频开黄腔")
    }

    func testConversationSafetyUsesObservableFlagsWithoutAScore() {
        let uncertainIdentity = Encounter(
            companionID: UUID(),
            kind: .flirting,
            conversationSafetyFlags: [.identityNotConfirmed]
        )
        XCTAssertFalse(uncertainIdentity.hasConversationSafetyConcern)

        let pressured = Encounter(
            companionID: UUID(),
            kind: .flirting,
            conversationSafetyFlags: [.pressuredForIntimateContent]
        )
        XCTAssertTrue(pressured.hasConversationSafetyConcern)
    }
}
