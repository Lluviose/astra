import XCTest
@testable import Astra

final class RecordingFlowTests: XCTestCase {
    @MainActor
    func testEmptyRosterCreatesDraftAndCancellationDoesNotCreateRecord() throws {
        try withApp { app in
            let flow = RecordingFlow()
            flow.begin(kind: .missed, app: app)
            let draft = try XCTUnwrap(flow.companionEditorTarget)
            XCTAssertEqual(draft.cityID, "")
            XCTAssertEqual(draft.stage, .new)
            XCTAssertEqual(draft.scorecard.completedCount, 0)
            XCTAssertFalse(flow.isPickingCompanion)
            flow.companionEditorTarget = nil
            flow.finishCompanionEditor(app: app)
            XCTAssertNil(flow.encounterTarget)
            XCTAssertTrue(app.companions.isEmpty)
            XCTAssertTrue(app.encounters.isEmpty)
            XCTAssertFalse(flow.recordAfterCreating)
        }
    }

    @MainActor
    func testAddFromPickerContinuesWithSavedPersonAndChosenOutcome() throws {
        try withApp { app in
            app.upsert(Companion(name: "已有的人"))
            let flow = RecordingFlow()
            flow.begin(kind: .missed, app: app)
            XCTAssertTrue(flow.isPickingCompanion)
            flow.selectNewCompanion()
            flow.isPickingCompanion = false
            flow.finishCompanionPicker(app: app)
            var draft = try XCTUnwrap(flow.companionEditorTarget)
            draft.cityID = "110000"
            app.upsert(draft)
            flow.companionEditorTarget = nil
            flow.finishCompanionEditor(app: app)
            XCTAssertEqual(flow.encounterTarget?.companionID, draft.id)
            XCTAssertEqual(flow.encounterTarget?.cityID, "110000")
            XCTAssertEqual(flow.encounterTarget?.kind, .missed)
            XCTAssertTrue(app.encounters.isEmpty)
        }
    }

    @MainActor
    func testStandaloneAddAndCancelledPickerNeverOpenRecord() throws {
        try withApp { app in
            let flow = RecordingFlow()
            flow.beginAddingCompanion(app: app)
            var draft = try XCTUnwrap(flow.companionEditorTarget)
            draft.cityID = "310000"
            app.upsert(draft)
            flow.companionEditorTarget = nil
            flow.finishCompanionEditor(app: app)
            XCTAssertNil(flow.encounterTarget)
            flow.begin(kind: .intimacy, app: app)
            flow.isPickingCompanion = false
            flow.finishCompanionPicker(app: app)
            XCTAssertNil(flow.encounterTarget)
            XCTAssertNil(flow.companionEditorTarget)
        }
    }

    @MainActor
    private func withApp(_ action: (AppState) throws -> Void) rethrows {
        let suiteName = "RecordingFlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LocalStore(defaults: defaults)
        store.save([Companion](), for: .companions)
        store.save([Encounter](), for: .encounters)
        try action(AppState(store: store, catalog: .shared, performsMediaMaintenance: false))
    }
}
