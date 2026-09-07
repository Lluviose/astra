import Foundation
import Observation
import SwiftUI

/// 选已有的人，或直接建档；只有人物保存成功后才接着记结果。
@MainActor
@Observable
final class RecordingFlow {
    var kind: EncounterKind = .intimacy
    var isPickingCompanion = false
    var companionEditorTarget: Companion?
    var encounterTarget: Encounter?
    private(set) var recordAfterCreating = false

    private var pendingCompanion: Companion?
    private var pendingAdd = false
    private var creatingCompanionID: UUID?

    func begin(kind: EncounterKind, app: AppState) {
        Haptics.shared.play(.lightTap)
        resetPending()
        self.kind = kind
        if app.currentCompanions.isEmpty {
            createCompanion(app: app, thenRecord: true)
        } else {
            isPickingCompanion = true
        }
    }

    func record(_ kind: EncounterKind, for companion: Companion) {
        resetPending()
        self.kind = kind
        encounterTarget = Encounter(companionID: companion.id, kind: kind, cityID: companion.cityID)
    }

    func beginAddingCompanion(app: AppState) {
        Haptics.shared.play(.lightTap)
        resetPending()
        createCompanion(app: app, thenRecord: false)
    }

    func select(_ companion: Companion) {
        pendingCompanion = companion
        pendingAdd = false
    }

    func selectNewCompanion() {
        pendingCompanion = nil
        pendingAdd = true
    }

    func finishCompanionPicker(app: AppState) {
        if pendingAdd {
            pendingAdd = false
            createCompanion(app: app, thenRecord: true)
        } else if let companion = pendingCompanion {
            pendingCompanion = nil
            encounterTarget = Encounter(companionID: companion.id, kind: kind, cityID: companion.cityID)
        }
    }

    func finishCompanionEditor(app: AppState) {
        defer { resetPending() }
        guard recordAfterCreating,
              let companionID = creatingCompanionID,
              let companion = app.companion(id: companionID)
        else { return }
        encounterTarget = Encounter(companionID: companion.id, kind: kind, cityID: companion.cityID)
    }

    private func createCompanion(app: AppState, thenRecord: Bool) {
        // 地点在档案内选，不把默认上海当作用户已确认的常驻地。
        let draft = app.makeDraftCompanion(cityID: "")
        recordAfterCreating = thenRecord
        creatingCompanionID = draft.id
        companionEditorTarget = draft
    }

    private func resetPending() {
        pendingCompanion = nil
        pendingAdd = false
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
                CompanionPickerSheet(onSelect: flow.select, onAdd: flow.selectNewCompanion)
            }
            .sheet(item: $flow.companionEditorTarget, onDismiss: { flow.finishCompanionEditor(app: app) }) { companion in
                CompanionEditor(companion: companion, recordAfterSaving: flow.recordAfterCreating)
            }
            .sheet(item: $flow.encounterTarget) { encounter in
                EncounterEditor(encounter: encounter)
            }
    }
}

extension View {
    func recordingFlowSheets(_ flow: RecordingFlow) -> some View {
        modifier(RecordingFlowSheets(flow: flow))
    }
}
