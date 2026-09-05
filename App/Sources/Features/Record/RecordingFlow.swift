import Foundation
import Observation
import SwiftUI

/// Person first. A sole active person opens directly; new people need no location gate.
@MainActor
@Observable
final class RecordingFlow {
    var kind: EncounterKind = .intimacy
    var isPickingCompanion = false
    var companionEditorTarget: Companion?
    var encounterTarget: Encounter?
    private(set) var recordAfterCreating = false
    private var pendingCompanion: Companion?
    private var wantsNewCompanion = false
    private var creatingCompanionID: UUID?

    func begin(kind: EncounterKind, app: AppState) {
        Haptics.shared.play(.lightTap)
        self.kind = kind
        resetPending()
        if app.currentCompanions.isEmpty {
            createCompanion(app: app, thenRecord: true)
        } else if app.currentCompanions.count == 1, let companion = app.currentCompanions.first {
            record(kind, for: companion)
        } else {
            isPickingCompanion = true
        }
    }

    func record(_ kind: EncounterKind, for companion: Companion) {
        self.kind = kind
        resetPending()
        encounterTarget = Encounter(companionID: companion.id, kind: kind,
                                    cityID: companion.cityID.isEmpty ? nil : companion.cityID)
    }

    func beginAddingCompanion(app: AppState) {
        resetPending()
        createCompanion(app: app, thenRecord: false)
    }

    func select(_ companion: Companion) { pendingCompanion = companion }
    func requestNewCompanion() { wantsNewCompanion = true }

    func finishCompanionPicker(app: AppState) {
        if wantsNewCompanion {
            wantsNewCompanion = false
            createCompanion(app: app, thenRecord: true)
        } else if let companion = pendingCompanion {
            record(kind, for: companion)
        }
    }

    func finishCompanionEditor(app: AppState) {
        defer { recordAfterCreating = false; creatingCompanionID = nil }
        guard recordAfterCreating, let id = creatingCompanionID,
              let companion = app.companion(id: id) else { return }
        encounterTarget = Encounter(companionID: id, kind: kind,
                                    cityID: companion.cityID.isEmpty ? nil : companion.cityID)
    }

    private func createCompanion(app: AppState, thenRecord: Bool) {
        let draft = app.makeDraftCompanion(cityID: "")
        recordAfterCreating = thenRecord
        creatingCompanionID = thenRecord ? draft.id : nil
        companionEditorTarget = draft
    }

    private func resetPending() {
        pendingCompanion = nil
        wantsNewCompanion = false
        recordAfterCreating = false
        creatingCompanionID = nil
    }
}

private struct RecordingFlowSheets: ViewModifier {
    let flow: RecordingFlow
    @Environment(AppState.self) private var app
    func body(content: Content) -> some View {
        @Bindable var flow = flow
        content
            .sheet(isPresented: $flow.isPickingCompanion, onDismiss: { flow.finishCompanionPicker(app: app) }) {
                CompanionPickerSheet(onSelect: { flow.select($0) }, onCreate: { flow.requestNewCompanion() })
            }
            .sheet(item: $flow.companionEditorTarget, onDismiss: { flow.finishCompanionEditor(app: app) }) { companion in
                CompanionEditor(companion: companion, continuesToRecord: flow.recordAfterCreating)
            }
            .sheet(item: $flow.encounterTarget) { EncounterEditor(encounter: $0) }
    }
}

extension View {
    func recordingFlowSheets(_ flow: RecordingFlow) -> some View {
        modifier(RecordingFlowSheets(flow: flow))
    }
}
