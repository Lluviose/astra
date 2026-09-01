import SwiftUI

/// 记录编辑器：基础信息保持快速，亲密细节按真实行为与本人感受展开。
struct EncounterEditor: View {

    let initial: Encounter

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Encounter
    @State private var costText: String
    @State private var hasFollowUpDate: Bool
    @State private var showBoundaryDetails: Bool
    @State private var showSafetyDetails: Bool
    @State private var showFollowUpDetails: Bool
    @State private var showDeleteConfirm = false
    @State private var showUnsavedAlert = false
    @State private var isPickingCity = false
    @FocusState private var isCostFocused: Bool
    @State private var sessionPhotoIDs: Set<String> = []
    @State private var viewingPhotoIndex: Int?

    private let maxPhotos = 8

    private var isNew: Bool { !app.encounters.contains { $0.id == initial.id } }
    private var companion: Companion? { app.companion(id: initial.companionID) }
    private var hasUnsavedChanges: Bool { draft != initial }

    private var availableFollowUps: [FollowUpKind] {
        if draft.kind.isIntimate { return FollowUpKind.allCases }
        return [.message, .planMeet, .accountSafety, .other]
    }

    init(encounter: Encounter) {
        self.initial = encounter
        _draft = State(initialValue: encounter)
        _costText = State(initialValue: encounter.cost.map { String(Int($0)) } ?? "")
        _hasFollowUpDate = State(initialValue: encounter.followUpDate != nil)
        _showBoundaryDetails = State(
            initialValue: encounter.boundaryFeeling != .notRecorded || !encounter.personalStates.isEmpty
        )
        _showSafetyDetails = State(
            initialValue: !encounter.safetyMeasures.isEmpty || !encounter.safetyNote.isEmpty
        )
        _showFollowUpDetails = State(initialValue: !encounter.followUpKinds.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                subjectSection
                basicsSection

                if draft.kind.isIntimate {
                    activitySection
                    climaxSection
                    boundarySection
                    safetySection
                }

                experienceSection
                photosSection
                followUpSection
                notesSection

                if !isNew {
                    Section {
                        Button("删除这条记录", role: .destructive) {
                            Haptics.shared.play(.warning)
                            showDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "记录结果" : "改记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { cancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .tint(Palette.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isCostFocused {
                        Spacer()
                        Button("完成") { isCostFocused = false }
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .alert("放弃未保存的修改？", isPresented: $showUnsavedAlert) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { abandon() }
            } message: {
                Text("关闭后，本次修改不会保留。")
            }
            .confirmationDialog(
                "删除这条记录？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    discardSessionPhotos()
                    app.delete(encounterID: initial.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .onChange(of: draft.kind) { _, kind in
                normalizeForKind(kind)
            }
            .onChange(of: draft.climaxDetails) { _, details in
                if details.contains(.creampie), draft.protectionStatus == .notRecorded {
                    draft.protectionStatus = .noProtection
                }
            }
            .onChange(of: draft.protectionStatus) { _, status in
                if status != .protected, status != .partial {
                    removeBarrierMeasures()
                }
            }
            .onChange(of: hasFollowUpDate) { _, hasDate in
                if hasDate, draft.followUpDate == nil {
                    draft.followUpDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                } else if !hasDate {
                    draft.followUpDate = nil
                }
            }
            .sheet(isPresented: Binding(
                get: { viewingPhotoIndex != nil },
                set: { if !$0 { viewingPhotoIndex = nil } }
            )) {
                PhotoViewer(ids: draft.photoIDs, index: viewingPhotoIndex ?? 0)
            }
            .sheet(isPresented: $isPickingCity) {
                CityPickerSheet(title: "这次在哪座城市") { city in
                    draft.cityID = city.id
                }
            }
        }
    }

    // MARK: - 快速基础记录

    @ViewBuilder
    private var subjectSection: some View {
        if let companion {
            Section("对象") {
                HStack(spacing: 12) {
                    AvatarView(companion: companion, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                        Text(app.cityName(for: companion))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var basicsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kindChoices) { kind in
                        kindChip(kind)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

            DatePicker("时间", selection: $draft.date, in: ...Date())

            Button {
                Haptics.shared.play(.lightTap)
                isPickingCity = true
            } label: {
                LabeledContent("城市") {
                    HStack(spacing: 5) {
                        Text(selectedCityName)
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField(
                draft.kind.isIntimate ? "酒店、住处等地点（可留空）" : "在哪一步没成（可留空）",
                text: $draft.place
            )
        } header: {
            Text("这次结果")
        } footer: {
            Text("只区分上床了还是没上床。时间和城市会进入时间线与猎场地图，细节以后再补也行。")
        }
    }

    // MARK: - 发生了什么

    private var activitySection: some View {
        Section {
            ForEach(IntimacyActivityGroup.allCases) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 7, lineSpacing: 8) {
                        ForEach(IntimacyActivity.allCases.filter { $0.group == group }) { activity in
                            GlassChip(
                                title: activity.label,
                                isOn: draft.activities.contains(activity),
                                tint: group == .heat || group == .place ? Palette.coral : Palette.accent,
                                compact: true
                            ) {
                                draft.activities = toggled(activity, in: draft.activities)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("床上做了什么")
        } footer: {
            Text("姿势、口、她骑上来、车震，发生了就勾。")
        }
    }

    private var climaxSection: some View {
        Section {
            FlowLayout(spacing: 7, lineSpacing: 8) {
                ForEach(ClimaxDetail.allCases) { detail in
                    GlassChip(
                        title: detail.label,
                        isOn: draft.climaxDetails.contains(detail),
                        tint: detail.tint,
                        compact: true
                    ) {
                        draft.climaxDetails = toggled(detail, in: draft.climaxDetails)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("这次怎么收的")
        } footer: {
            Text("无套、内射、口爆、颜射分开勾。她高潮了也可以记。")
        }
    }

    private var boundarySection: some View {
        Section {
            DisclosureGroup(isExpanded: $showBoundaryDetails) {
                Picker("边界感受", selection: $draft.boundaryFeeling) {
                    ForEach(BoundaryFeeling.allCases) { feeling in
                        Label(feeling.label, systemImage: feeling.symbolName)
                            .tag(feeling)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("我的当时状态")
                        .font(.subheadline)

                    FlowLayout(spacing: 7, lineSpacing: 8) {
                        ForEach(PersonalState.allCases) { state in
                            GlassChip(
                                title: state.label,
                                isOn: draft.personalStates.contains(state),
                                tint: state == .clearheaded ? Palette.safe : Palette.warning,
                                compact: true
                            ) {
                                togglePersonalState(state)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                if draft.boundaryFeeling.needsFollowUp {
                    Label("要是心里打鼓，下面可以勾「回个消息」或去做检测。", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(Palette.warning)
                }
            } label: {
                Label("边界与当时状态", systemImage: "person.crop.circle.badge.checkmark")
            }
        } footer: {
            Text("这是你的事后回看，不替代双方当时清醒、明确且持续的同意。")
        }
    }

    // MARK: - 防护与健康

    private var safetySection: some View {
        Section {
            Picker("有没有戴套", selection: $draft.protectionStatus) {
                ForEach(ProtectionStatus.allCases) { status in
                    Label(status.label, systemImage: status.symbolName)
                        .tag(status)
                }
            }

            DisclosureGroup(isExpanded: $showSafetyDetails) {
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(SafetyMeasure.allCases) { measure in
                        GlassChip(
                            title: measure.label,
                            isOn: draft.safetyMeasures.contains(measure),
                            tint: Palette.safe,
                            compact: true
                        ) {
                            toggleSafetyMeasure(measure)
                        }
                    }
                }
                .padding(.vertical, 4)

            TextField("检测、有没有戴套、身体情况（可选）", text: $draft.safetyNote, axis: .vertical)
                    .lineLimit(2...4)
            } label: {
                Label("具体方式与备忘", systemImage: "checkmark.shield.fill")
            }

            if draft.protectionStatus.hasBarrierGap {
                Label(barrierGuidanceText, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("套和健康")
        } footer: {
            Text("戴套、吃药、避孕不是一回事。无套和内射分开记。")
        }
    }

    // MARK: - 本人感受与决定

    private var experienceSection: some View {
        Section {
            if draft.kind.isIntimate {
                experiencePicker(
                    title: "身体感受",
                    rating: $draft.physicalRating,
                    emojis: ["😣", "😕", "😐", "😋", "🥵"]
                )
            }

            experiencePicker(
                title: "情绪感受",
                rating: $draft.emotionalRating,
                emojis: ["😞", "😕", "😐", "🙂", "😊"]
            )

            Picker(continuationPrompt, selection: $draft.meetAgainIntent) {
                ForEach(MeetAgainIntent.allCases) { intent in
                    Text(intent.label).tag(intent)
                }
            }
        } header: {
            Text(draft.kind.isIntimate ? "爽不爽，还想不想再干" : "这次感觉与下一步")
        } footer: {
            Text("记你自己的感觉就行，不用给她打分。")
        }
    }

    // MARK: - 后续处理

    private var followUpSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showFollowUpDetails) {
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(availableFollowUps) { kind in
                        GlassChip(
                            title: kind.label,
                            systemImage: kind.symbolName,
                            isOn: draft.followUpKinds.contains(kind),
                            tint: Palette.warning,
                            compact: true
                        ) {
                            toggleFollowUp(kind)
                        }
                    }
                }
                .padding(.vertical, 4)

                if !draft.followUpKinds.isEmpty {
                    Toggle("设置处理日期", isOn: $hasFollowUpDate)

                    if hasFollowUpDate {
                        DatePicker(
                            "处理日期",
                            selection: followUpDateBinding,
                            displayedComponents: .date
                        )
                    }

                    TextField("具体要做什么（可选）", text: $draft.followUpNote, axis: .vertical)
                        .lineLimit(2...4)

                    Toggle("已经处理完成", isOn: $draft.isFollowUpDone)
                }

                if draft.followUpKinds.contains(.exposureConsult) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("担心近期 HIV 暴露时，请立即联系医疗机构", systemImage: "cross.case.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("PEP 需在可能暴露后 72 小时内开始，越早越好。本应用不能判断风险，也不能替代医疗建议。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } label: {
                HStack {
                    Label("需要后续处理吗", systemImage: "checklist")
                    Spacer()
                    if draft.hasPendingFollowUp {
                        Text("待处理")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.warning)
                    }
                }
            }
        } footer: {
            Text("跟进全靠你自己勾。没勾就不会烦你。")
        }
    }

    private var notesSection: some View {
        Section("补充") {
            HStack {
                Text("花费")
                Spacer()
                TextField("0", text: $costText)
                    .keyboardType(.numberPad)
                    .focused($isCostFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .onChange(of: costText) { _, newValue in
                        draft.cost = Double(newValue.filter { $0.isNumber })
                    }
                Text("元")
                    .foregroundStyle(.secondary)
            }

            TextField(
                draft.kind.isIntimate
                    ? "她哪里敏感、叫得怎么样、下次想怎么玩"
                    : "为什么没上床、下次要不要换时间或城市",
                text: $draft.note,
                axis: .vertical
            )
                .lineLimit(3...6)
        }
    }

    // MARK: - 组件与状态

    private var kindChoices: [EncounterKind] {
        return EncounterKind.recordableCases
    }

    private var selectedCityName: String {
        if let cityID = draft.cityID, let city = app.city(id: cityID) {
            return city.name
        }
        if let companion {
            return app.cityName(for: companion)
        }
        return "选择城市"
    }

    private func kindChip(_ kind: EncounterKind) -> some View {
        Button {
            draft.kind = kind
        } label: {
            HStack(spacing: 5) {
                if draft.kind == kind {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                }
                Image(systemName: kind.symbolName).font(.system(size: 12, weight: .semibold))
                Text(kind.label).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(draft.kind == kind ? .white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if draft.kind == kind {
                    Capsule().fill(kind.tint.gradient)
                }
            }
            .glassCapsule(interactive: true, shadowRadius: 8)
        }
        .buttonStyle(HapticButtonStyle(cue: .selection))
    }

    private func experiencePicker(
        title: String,
        rating: Binding<Int>,
        emojis: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                if rating.wrappedValue == 0 {
                    Text("未记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("清除") {
                        rating.wrappedValue = 0
                    }
                    .font(.caption)
                }
            }

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        Haptics.shared.play(.selection)
                        rating.wrappedValue = value
                    } label: {
                        Text(emojis[value - 1])
                            .font(.title3)
                            .opacity(rating.wrappedValue == value ? 1 : 0.3)
                            .scaleEffect(rating.wrappedValue == value ? 1.16 : 1)
                            .animation(
                                .spring(response: 0.25, dampingFraction: 0.65),
                                value: rating.wrappedValue
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(value) 分")
                    .accessibilityAddTraits(rating.wrappedValue == value ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 3)
    }

    private var followUpDateBinding: Binding<Date> {
        Binding(
            get: { draft.followUpDate ?? Date() },
            set: { draft.followUpDate = $0 }
        )
    }

    private var continuationPrompt: String {
        draft.kind.isIntimate ? "还想再上床吗" : "还想再约吗"
    }

    private var photosSection: some View {
        Section {
            if !draft.photoIDs.isEmpty {
                PhotoStrip(
                    ids: draft.photoIDs,
                    editable: true,
                    onDelete: removePhoto,
                    onOpen: { viewingPhotoIndex = $0 }
                )
            }

            if draft.photoIDs.count < maxPhotos {
                PhotoAddBar(
                    selectionLimit: maxPhotos - draft.photoIDs.count,
                    onImported: addPhotos
                )
            }
        } header: {
            Text("这次的照片")
        } footer: {
            Text("最多 \(maxPhotos) 张。不进系统相册或开发者服务器，可随设备 iCloud Backup 恢复。")
        }
    }

    private func addPhotos(_ importedIDs: [String]) {
        let room = maxPhotos - draft.photoIDs.count
        let accepted = Array(importedIDs.prefix(max(0, room)))
        draft.photoIDs.append(contentsOf: accepted)
        sessionPhotoIDs.formUnion(accepted)
        MediaStore.delete(ids: Array(importedIDs.dropFirst(accepted.count)))
        Haptics.shared.play(.toggleOn)
    }

    private func removePhoto(_ id: String) {
        draft.photoIDs.removeAll { $0 == id }
        if sessionPhotoIDs.contains(id) {
            MediaStore.delete(id: id)
            sessionPhotoIDs.remove(id)
        }
    }

    private func discardSessionPhotos() {
        MediaStore.delete(ids: Array(sessionPhotoIDs))
        sessionPhotoIDs.removeAll()
    }

    private var barrierGuidanceText: String {
        switch draft.protectionStatus {
        case .partial:
            "部分行为使用屏障不等于具体风险结论；可以在备忘里记清对应行为，需要时安排检测或咨询。"
        case .noProtection:
            "“未用屏障”本身不等于风险结论；是否需要处理取决于具体行为。你可以在下方安排检测或咨询。"
        default:
            ""
        }
    }

    private func toggled<T: Hashable>(_ value: T, in set: Set<T>) -> Set<T> {
        var copy = set
        if copy.contains(value) {
            copy.remove(value)
        } else {
            copy.insert(value)
        }
        return copy
    }

    private func togglePersonalState(_ state: PersonalState) {
        if state == .clearheaded {
            draft.personalStates = draft.personalStates.contains(.clearheaded) ? [] : [.clearheaded]
            return
        }

        draft.personalStates.remove(.clearheaded)
        draft.personalStates = toggled(state, in: draft.personalStates)
    }

    private func toggleSafetyMeasure(_ measure: SafetyMeasure) {
        let wasSelected = draft.safetyMeasures.contains(measure)
        draft.safetyMeasures = toggled(measure, in: draft.safetyMeasures)

        guard measure.isBarrier, !wasSelected else { return }
        switch draft.protectionStatus {
        case .noProtection:
            draft.protectionStatus = .partial
        case .notRecorded, .notApplicable:
            draft.protectionStatus = .protected
        case .protected, .partial:
            break
        }
    }

    private func removeBarrierMeasures() {
        draft.safetyMeasures = Set(draft.safetyMeasures.filter { !$0.isBarrier })
    }

    private func toggleFollowUp(_ kind: FollowUpKind) {
        draft.followUpKinds = toggled(kind, in: draft.followUpKinds)
        if draft.followUpKinds.isEmpty {
            draft.followUpDate = nil
            draft.followUpNote = ""
            draft.isFollowUpDone = false
            hasFollowUpDate = false
        } else {
            draft.isFollowUpDone = false
        }
    }

    private func normalizeForKind(_ kind: EncounterKind) {
        draft.kind = kind
        draft.normalizeForOutcome()
        hasFollowUpDate = draft.followUpDate != nil
    }

    private func save() {
        normalizeForKind(draft.kind)
        draft.physicalRating = min(max(draft.physicalRating, 0), 5)
        draft.emotionalRating = min(max(draft.emotionalRating, 0), 5)
        if draft.followUpKinds.isEmpty {
            draft.followUpDate = nil
            draft.followUpNote = ""
            draft.isFollowUpDone = false
        }
        if draft.protectionStatus != .protected, draft.protectionStatus != .partial {
            removeBarrierMeasures()
        }
        sessionPhotoIDs.removeAll()
        app.upsert(draft)
        dismiss()
    }

    private func cancel() {
        if hasUnsavedChanges {
            showUnsavedAlert = true
        } else {
            discardSessionPhotos()
            dismiss()
        }
    }

    private func abandon() {
        discardSessionPhotos()
        dismiss()
    }
}
