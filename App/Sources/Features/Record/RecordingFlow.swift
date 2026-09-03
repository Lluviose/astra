import Foundation
import Observation
import SwiftUI

/// 「记一笔」的多步流程：选人 → （没人时先选地点建档）→ 打开记录编辑器。
///
/// 首页和时间线共用同一套状态机，避免两份几乎一样的 sheet 编排。
/// 视图只需持有一个 `@State var flow = RecordingFlow()` 并挂上 `.recordingFlowSheets(flow)`。
@MainActor
@Observable
final class RecordingFlow {

    var kind: EncounterKind = .intimacy

    var isPickingCompanion = false
    var isPickingLocation = false
    var companionEditorTarget: Companion?
    var encounterTarget: Encounter?

    /// 选地点面板的标题；建档和「先加个人再记」用不同措辞。
    private(set) var locationPickerTitle = "常驻或常见面的地点"

    private var pendingCompanion: Companion?
    private var pendingLocation: City?
    private var recordAfterCreating = false
    private var creatingCompanionID: UUID?

    // MARK: - 入口

    /// 记一笔：有人就选人，名册还空着就先建档。
    func begin(kind: EncounterKind, app: AppState) {
        Haptics.shared.play(.lightTap)
        self.kind = kind
        pendingCompanion = nil
        pendingLocation = nil
        creatingCompanionID = nil
        if app.currentCompanions.isEmpty {
            recordAfterCreating = true
            locationPickerTitle = "先记下她常驻的地点"
            isPickingLocation = true
        } else {
            recordAfterCreating = false
            isPickingCompanion = true
        }
    }

    /// 已经知道是谁，直接进编辑器。
    func record(_ kind: EncounterKind, for companion: Companion) {
        self.kind = kind
        pendingCompanion = nil
        recordAfterCreating = false
        creatingCompanionID = nil
        encounterTarget = Encounter(companionID: companion.id, kind: kind, cityID: companion.cityID)
    }

    /// 只是加个人，不接着记。
    func beginAddingCompanion() {
        Haptics.shared.play(.lightTap)
        recordAfterCreating = false
        creatingCompanionID = nil
        pendingLocation = nil
        locationPickerTitle = "常驻或常见面的地点"
        isPickingLocation = true
    }

    // MARK: - 面板回调

    func select(_ companion: Companion) {
        pendingCompanion = companion
    }

    func select(_ location: City) {
        pendingLocation = location
    }

    func finishCompanionPicker() {
        guard let companion = pendingCompanion else { return }
        pendingCompanion = nil
        encounterTarget = Encounter(companionID: companion.id, kind: kind, cityID: companion.cityID)
    }

    func finishLocationPicker(app: AppState) {
        guard let location = pendingLocation else {
            recordAfterCreating = false
            creatingCompanionID = nil
            return
        }
        pendingLocation = nil
        let draft = app.makeDraftCompanion(cityID: location.id)
        if recordAfterCreating { creatingCompanionID = draft.id }
        companionEditorTarget = draft
    }

    func finishCompanionEditor(app: AppState) {
        defer {
            recordAfterCreating = false
            creatingCompanionID = nil
        }
        guard recordAfterCreating,
              let companionID = creatingCompanionID,
              let companion = app.companion(id: companionID)
        else { return }
        encounterTarget = Encounter(companionID: companion.id, kind: kind, cityID: companion.cityID)
    }
}

// MARK: - Sheet 编排

private struct RecordingFlowSheets: ViewModifier {
    let flow: RecordingFlow

    @Environment(AppState.self) private var app

    func body(content: Content) -> some View {
        @Bindable var flow = flow
        content
            .sheet(isPresented: $flow.isPickingCompanion, onDismiss: { flow.finishCompanionPicker() }) {
                CompanionPickerSheet { companion in
                    flow.select(companion)
                }
            }
            .sheet(isPresented: $flow.isPickingLocation, onDismiss: { flow.finishLocationPicker(app: app) }) {
                CityPickerSheet(title: flow.locationPickerTitle) { location in
                    flow.select(location)
                }
            }
            .sheet(item: $flow.companionEditorTarget, onDismiss: { flow.finishCompanionEditor(app: app) }) { companion in
                CompanionEditor(companion: companion)
            }
            .sheet(item: $flow.encounterTarget) { encounter in
                EncounterEditor(encounter: encounter)
            }
    }
}

extension View {
    /// 挂上「记一笔」流程需要的全部面板。
    func recordingFlowSheets(_ flow: RecordingFlow) -> some View {
        modifier(RecordingFlowSheets(flow: flow))
    }
}
