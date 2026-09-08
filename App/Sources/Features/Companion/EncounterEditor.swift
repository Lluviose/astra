import SwiftUI

/// 记录编辑器：结果、时间、地点填了就能存；上床了再往下补节奏、玩法、收尾、套和感受。
struct EncounterEditor: View {

    let initial: Encounter

    private enum Page: Int, CaseIterable, Identifiable {
        case result, details, followUp
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .result: "结果"
            case .details: "细节"
            case .followUp: "跟进"
            }
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var movingForward = true
    @State private var page: Page = .result
    @State private var showTemplateConfirm = false
    @State private var hasIntimateDraft: Bool

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
    private let roundChoices = [1, 2, 3, 4, 5]

    private var isNew: Bool { !app.encounters.contains { $0.id == initial.id } }
    private var companion: Companion? { app.companion(id: initial.companionID) }
    private var hasUnsavedChanges: Bool {
        draft != initial || costText != (initial.cost.map { String($0) } ?? "")
    }
    private var parsedCost: Double? { Double(costText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var isCostValid: Bool {
        costText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (parsedCost.map { $0.isFinite && $0 >= 0 } ?? false)
    }
    private var canSave: Bool {
        companion != nil && isCostValid && draft.date <= Date()
            && app.location(id: draft.cityID ?? companion?.cityID ?? "") != nil
    }

    /// 上一次上床的记录；新建上床记录时可以一键沿用。
    private var lastHookup: Encounter? {
        guard isNew, draft.kind.isIntimate else { return nil }
        return app.lastHookup(for: initial.companionID)
    }

    private var availableFollowUps: [FollowUpKind] {
        if draft.kind.isIntimate { return FollowUpKind.allCases }
        return [.message, .planMeet, .accountSafety, .other]
    }

    init(encounter: Encounter) {
        self.initial = encounter
        _hasIntimateDraft = State(initialValue: encounter.kind.isIntimate)
        _draft = State(initialValue: encounter)
        _costText = State(initialValue: encounter.cost.map { String($0) } ?? "")
        _hasFollowUpDate = State(initialValue: encounter.followUpDate != nil)
        _showBoundaryDetails = State(
            initialValue: encounter.boundaryFeeling != .notRecorded || !encounter.personalStates.isEmpty
        )
        _showSafetyDetails = State(
            initialValue: !encounter.safetyMeasures.isEmpty || !encounter.safetyNote.isEmpty
        )
        _showFollowUpDetails = State(initialValue: true)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NativeEditorHeader(steps: editorSteps, selection: pageSelection)
                ZStack {
                    editorForm
                        .id(page)
                        .transition(NativeEditorMotion.transition(forward: movingForward, reduceMotion: reduceMotion))
                }
                .clipped()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isNew ? "记录这次约炮" : "编辑约炮记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { cancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .tint(Palette.accent)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("上一步") { changePage(Page(rawValue: page.rawValue - 1) ?? .result) }
                        .disabled(page == .result)
                    Spacer()
                    Text("\(page.rawValue + 1) / 3").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if page != .followUp {
                        Button("下一步") { changePage(Page(rawValue: page.rawValue + 1) ?? .followUp) }
                    } else {
                        Button("保存记录") { save() }.disabled(!canSave)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isCostFocused {
                        Spacer()
                        Button("完成") { isCostFocused = false }
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .onChange(of: draft.kind) { _, kind in
                // 从没上床首次改成上床时，不把模型的“不适用”当成这次已选防护。
                if kind.isIntimate, !hasIntimateDraft {
                    draft.protectionStatus = .notRecorded
                    hasIntimateDraft = true
                }
            }
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
            .alert("替换当前行为和收尾？", isPresented: $showTemplateConfirm) {
                Button("取消", role: .cancel) {}
                Button("复用上次") {
                    if let lastHookup { applyTemplate(from: lastHookup) }
                }
            } message: {
                Text("只替换这两组细节，请按这次实际情况核对。")
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
                CityPickerSheet(title: "这次在哪", selectedID: draft.cityID) { city in
                    draft.cityID = city.id
                }
            }
        }
    }

    private var editorForm: some View {
            Form {
                if !isCostValid {
                    Section {
                        Button("花费格式不对，点这里修改") { changePage(.details) }
                            .foregroundStyle(Palette.warning)
                    }
                }
                switch page {
                case .result:
                    subjectSection
                    outcomeSection
                    timeSection
                    placeSection
                    if draft.kind.isMissed { missedSection }
                case .details:
                    if draft.kind.isIntimate {
                        rhythmSection
                        activitySection
                        climaxSection
                        safetySection
                        boundarySection
                    }
                    experienceSection
                    notesSection
                    photosSection
                case .followUp:
                    reviewSection
                    followUpSection
                    if !isNew {
                        Section {
                            Button("删除这条记录", role: .destructive) {
                                Haptics.shared.play(.warning)
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .animation(NativeEditorMotion.animation(reduceMotion: reduceMotion), value: draft.kind)
            .scrollDismissesKeyboard(.interactively)
    }

    private var editorSteps: [NativeEditorStep] {
        [
            NativeEditorStep(title: "结果", subtitle: "上床了还是没上床，确认时间和地点就能存。", symbol: "checkmark.circle"),
            NativeEditorStep(
                title: "细节",
                subtitle: draft.kind.isIntimate ? "谁主动、几轮多久、玩法、收尾、套和感受，按需补。" : "记录感受、花费、备注和照片。",
                symbol: "slider.horizontal.3"
            ),
            NativeEditorStep(title: "跟进", subtitle: "看一眼记录，再决定要不要联系或处理后续。", symbol: "checklist")
        ]
    }

    private var pageSelection: Binding<Int> {
        Binding(get: { page.rawValue }, set: { changePage(Page(rawValue: $0) ?? page) })
    }

    private func changePage(_ next: Page) {
        guard next != page else { return }
        NativeEditorMotion.dismissKeyboard()
        movingForward = next.rawValue > page.rawValue
        Haptics.shared.play(.selection)
        withAnimation(NativeEditorMotion.animation(reduceMotion: reduceMotion)) { page = next }
    }

    // MARK: - 对象

    @ViewBuilder
    private var subjectSection: some View {
        if let companion {
            Section {
                HStack(spacing: 12) {
                    AvatarView(companion: companion, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                        Text("\(companion.stage.label) · \(app.locationName(for: companion)) · 上床 \(app.hookupCount(for: companion.id)) 次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !companion.turnOns.isEmpty, draft.kind.isIntimate {
                    Label {
                        Text(companion.turnOns)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundStyle(Palette.coral)
                    }
                }

                if let lastHookup {
                    Button {
                        if draft.activities.isEmpty && draft.climaxDetails.isEmpty {
                            applyTemplate(from: lastHookup)
                        } else {
                            showTemplateConfirm = true
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("复用上次的行为和收尾")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(Format.relativeDay(lastHookup.date)) · \(templateSummary(for: lastHookup))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        } icon: {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(Palette.coral)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("对象")
            }
        }
    }

    private func templateSummary(for encounter: Encounter) -> String {
        var parts: [String] = []
        if !encounter.activitySummary.isEmpty { parts.append(encounter.activitySummary) }
        if !encounter.climaxSummary.isEmpty { parts.append(encounter.climaxSummary) }
        return parts.isEmpty ? "上次没记细节" : parts.joined(separator: " · ")
    }

    private func applyTemplate(from encounter: Encounter) {
        draft.reuseDetails(from: encounter)
        Haptics.shared.play(.success)
    }

    // MARK: - 结果 / 时间 / 地点

    private var outcomeSection: some View {
        Section {
            GlassStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(EncounterKind.recordableCases) { kind in
                        OutcomeCard(kind: kind, isOn: draft.kind == kind) {
                            draft.kind = kind
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            Text("这次结果")
        } footer: {
            Text("切换结果会保留当前草稿，保存时只保留对应结果的字段。")
        }
    }

    private var timeSection: some View {
        Section {
            FlowLayout(spacing: 7, lineSpacing: 8) {
                ForEach(QuickDateChoice.allCases) { choice in
                    RecordChoice(
                        title: choice.label,
                        systemImage: "clock",
                        isOn: QuickDateChoice.matching(draft.date) == choice,
                        compact: true
                    ) {
                        draft.date = choice.date()
                    }
                }
            }
            .padding(.vertical, 4)

            DatePicker("具体时间", selection: $draft.date, in: ...Date())
        } header: {
            Text("什么时候")
        } footer: {
            Text("刚从酒店出来点「刚刚」，第二天补记点「昨晚」，再细调具体时间。")
        }
    }

    private var placeSection: some View {
        Section {
            Button {
                Haptics.shared.play(.lightTap)
                isPickingCity = true
            } label: {
                LabeledContent("城市 / 国家") {
                    HStack(spacing: 5) {
                        Text(selectedLocationName)
                        ChevronHint()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: "场所",
                    systemImage: "mappin.and.ellipse",
                    selectedCount: draft.venueCategory == .notRecorded ? 0 : 1
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(VenueCategory.choices) { category in
                        RecordChoice(
                            title: category.shortLabel,
                            systemImage: category.symbolName,
                            isOn: draft.venueCategory == category,
                            compact: true
                        ) {
                            draft.venueCategory = draft.venueCategory == category ? .notRecorded : category
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            TextField("具体场所备注：哪家酒店、几号房、她家几楼（可留空）", text: $draft.place, axis: .vertical)
                .lineLimit(1...3)
        } header: {
            Text("在哪")
        } footer: {
            Text("常驻地点已带入，请确认这次实际在哪。场所只记类型，不把“在哪一步没成”写进地点。")
        }
    }

    private var missedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: "到了哪一步 · 单选",
                    systemImage: "figure.walk.motion",
                    selectedCount: draft.missedProgress == .notRecorded ? 0 : 1
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(MissedProgress.allCases.filter { $0 != .notRecorded }) { progress in
                        RecordChoice(title: progress.label, isOn: draft.missedProgress == progress, tint: EncounterKind.missed.tint, compact: true) {
                            draft.missedProgress = draft.missedProgress == progress ? .notRecorded : progress
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: "为什么没上床 · 可多选",
                    systemImage: "questionmark.bubble",
                    selectedCount: draft.missedReasons.count
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(MissedReason.allCases) { reason in
                        RecordChoice(title: reason.label, isOn: draft.missedReasons.contains(reason), tint: Palette.accent, compact: true) {
                            draft.missedReasons = toggled(reason, in: draft.missedReasons)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("没上床的情况")
        } footer: {
            Text("没上床也可能是双方的选择。只记知道的原因，不确定就留空。")
        }
    }

    // MARK: - 保存前看一眼

    private var reviewSection: some View {
        Section("保存前看一眼") {
            LabeledContent("结果", value: draft.kind.label)
            LabeledContent("时间", value: draft.date.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("地点", value: selectedLocationName)
            if draft.venueCategory != .notRecorded {
                LabeledContent("场所", value: draft.venueCategory.label)
            }
            if draft.kind.isIntimate {
                if !draft.rhythmSummary.isEmpty {
                    LabeledContent("节奏", value: draft.rhythmSummary)
                }
                LabeledContent("戴套", value: draft.protectionStatus.label)
                if !draft.activitySummary.isEmpty { Text(draft.activitySummary) }
                if !draft.climaxSummary.isEmpty { Text(draft.climaxSummary) }
            } else if !draft.missedSummary.isEmpty {
                Text(draft.missedSummary)
            }
            if let cost = parsedCost, cost > 0 {
                LabeledContent("花费", value: Format.money(cost))
            }
            if !draft.photoIDs.isEmpty {
                LabeledContent("照片", value: "\(draft.photoIDs.count) 张")
            }
            LabeledContent(draft.kind.isIntimate ? "还想再上吗" : "还约不约", value: draft.meetAgainIntent.label)
        }
    }

    // MARK: - 节奏

    private var rhythmSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: "谁主动",
                    systemImage: "arrow.left.arrow.right",
                    selectedCount: draft.initiator.isRecorded ? 1 : 0,
                    tint: Palette.coral
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(Initiator.allCases.filter(\.isRecorded)) { initiator in
                        RecordChoice(
                            title: initiator.label,
                            systemImage: initiator.symbolName,
                            isOn: draft.initiator == initiator,
                            tint: Palette.coral,
                            compact: true
                        ) {
                            draft.initiator = draft.initiator == initiator ? .notRecorded : initiator
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: "几轮",
                    systemImage: "repeat",
                    selectedCount: draft.rounds == nil ? 0 : 1,
                    tint: Palette.coral
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(roundChoices, id: \.self) { count in
                        RecordChoice(
                            title: count == roundChoices.last ? "\(count) 轮以上" : "\(count) 轮",
                            isOn: draft.rounds == count,
                            tint: Palette.coral,
                            compact: true
                        ) {
                            setRounds(draft.rounds == count ? nil : count)
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: durationTitle,
                    systemImage: "timer",
                    selectedCount: draft.durationMinutes == nil ? 0 : 1,
                    tint: Palette.coral
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(DurationPreset.allCases) { preset in
                        RecordChoice(
                            title: preset.label,
                            isOn: draft.durationMinutes == preset.minutes,
                            tint: Palette.coral,
                            compact: true
                        ) {
                            draft.durationMinutes = draft.durationMinutes == preset.minutes ? nil : preset.minutes
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("节奏")
        } footer: {
            Text("凭印象选就行，用来算平均几轮、平均多久。选了 2 轮以上会自动勾上「多轮」。")
        }
    }

    private var durationTitle: String {
        guard let minutes = draft.durationMinutes,
              !DurationPreset.allCases.contains(where: { $0.minutes == minutes })
        else { return "多久" }
        return "多久 · 已记 \(Encounter.durationText(minutes: minutes))"
    }

    private func setRounds(_ value: Int?) {
        draft.rounds = value
        guard let value else { return }
        if value >= 2 {
            draft.activities.insert(.multipleRounds)
        } else {
            draft.activities.remove(.multipleRounds)
        }
    }

    // MARK: - 套

    private var safetySection: some View {
        Section {
            FlowLayout(spacing: 7, lineSpacing: 8) {
                ForEach(ProtectionStatus.allCases) { status in
                    RecordChoice(
                        title: status.label,
                        systemImage: status.symbolName,
                        isOn: draft.protectionStatus == status,
                        tint: status.tint,
                        compact: true
                    ) {
                        draft.protectionStatus = draft.protectionStatus == status ? .notRecorded : status
                    }
                }
            }
            .padding(.vertical, 4)

            DisclosureGroup(isExpanded: $showSafetyDetails) {
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(SafetyMeasure.allCases) { measure in
                        RecordChoice(
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

                TextField("检测、吃药、身体情况（可选）", text: $draft.safetyNote, axis: .vertical)
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
            Text("戴套与其他防护 · 按这次实际情况选")
        } footer: {
            Text("戴套、吃药、避孕不是一回事。无套和内射分开记。")
        }
    }

    // MARK: - 做了什么

    private var activitySection: some View {
        Section {
            ForEach(IntimacyActivityGroup.allCases) { group in
                let options = group.activities
                VStack(alignment: .leading, spacing: 8) {
                    ChoiceGroupHeader(
                        title: group.label,
                        systemImage: group.symbolName,
                        selectedCount: options.filter { draft.activities.contains($0) }.count,
                        tint: group == .heat || group == .place || group == .rhythm ? Palette.coral : Palette.accent
                    )
                    FlowLayout(spacing: 7, lineSpacing: 8) {
                        ForEach(options) { activity in
                            RecordChoice(
                                title: activity.label,
                                systemImage: activity.symbolName,
                                isOn: draft.activities.contains(activity),
                                tint: group == .heat || group == .place || group == .rhythm ? Palette.coral : Palette.accent,
                                compact: true
                            ) {
                                toggleActivity(activity)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("做了什么 · 可多选")
                Spacer()
                if !draft.activities.isEmpty {
                    Text("\(draft.activities.count) 项")
                        .contentTransition(.numericText())
                }
            }
        } footer: {
            Text("按实际发生的行为勾选；没记的留空，没列出的写在补充备注。")
        }
    }

    private func toggleActivity(_ activity: IntimacyActivity) {
        draft.activities = toggled(activity, in: draft.activities)
        // 勾了「多轮」但还没选几轮时，默认按 2 轮记；取消「多轮」不动已经明确选好的轮数。
        if activity == .multipleRounds, draft.activities.contains(.multipleRounds), draft.rounds == nil {
            draft.rounds = 2
        }
    }

    private var climaxSection: some View {
        Section {
            ForEach(ClimaxDetailGroup.allCases) { group in
                let options = group.details
                VStack(alignment: .leading, spacing: 8) {
                    ChoiceGroupHeader(
                        title: group.label,
                        selectedCount: options.filter { draft.climaxDetails.contains($0) }.count,
                        tint: Palette.coral
                    )
                    FlowLayout(spacing: 7, lineSpacing: 8) {
                        ForEach(options) { detail in
                            RecordChoice(title: detail.label, isOn: draft.climaxDetails.contains(detail), tint: detail.tint, compact: true) {
                                draft.toggleClimax(detail)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("高潮与射精 · 可多选")
        } footer: {
            Text("她的感受不确定就选不确定。多轮可以记录多种收尾，戴套情况单独选。")
        }
    }

    // MARK: - 感受与下一步

    private var experienceSection: some View {
        Section {
            if draft.kind.isIntimate {
                experiencePicker(
                    title: "身体感受",
                    rating: $draft.physicalRating,
                    emojis: ["😣", "😕", "😐", "😋", "🥵"],
                    labels: ["很不爽", "不太爽", "一般", "爽", "很爽"]
                )
            }

            experiencePicker(
                title: "情绪感受",
                rating: $draft.emotionalRating,
                emojis: ["😞", "😕", "😐", "🙂", "😊"],
                labels: ["很差", "不太好", "一般", "开心", "很开心"]
            )

            VStack(alignment: .leading, spacing: 8) {
                ChoiceGroupHeader(
                    title: draft.kind.isIntimate ? "还想再上吗" : "还想再约吗",
                    systemImage: "arrow.triangle.2.circlepath",
                    selectedCount: draft.meetAgainIntent == .notRecorded ? 0 : 1
                )
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(MeetAgainIntent.allCases.filter { $0 != .notRecorded }) { intent in
                        RecordChoice(
                            title: intent.label,
                            isOn: draft.meetAgainIntent == intent,
                            tint: intent == .no ? Color.secondary : Palette.accent,
                            compact: true
                        ) {
                            draft.meetAgainIntent = draft.meetAgainIntent == intent ? .notRecorded : intent
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(draft.kind.isIntimate ? "爽不爽，还想不想" : "感觉与下一步")
        } footer: {
            Text("记你自己的感觉就行，不用给她打分。")
        }
    }

    // MARK: - 照片与补充

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
            HStack {
                Text("这次的照片")
                Spacer()
                Text("\(draft.photoIDs.count) / \(maxPhotos)")
            }
        } footer: {
            Text("最多 \(maxPhotos) 张，会一起进她的艳照私藏。不进系统相册。")
        }
    }

    private var notesSection: some View {
        Section("补充") {
            HStack {
                Text("花费")
                Spacer()
                TextField("未记录", text: $costText)
                    .keyboardType(.decimalPad)
                    .focused($isCostFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .onChange(of: costText) { _, _ in draft.cost = parsedCost }
                Text("元")
                    .foregroundStyle(.secondary)
            }

            if !isCostValid {
                Text("花费用非负数字填写，可带小数；不记就留空。")
                    .font(.caption).foregroundStyle(Palette.warning)
            }
            TextField(
                draft.kind.isIntimate
                    ? "她说了什么、哪一下最带劲、下次想试什么"
                    : "为什么没上床、下次要不要换时间或地点",
                text: $draft.note,
                axis: .vertical
            )
                .lineLimit(3...6)
        }
    }

    // MARK: - 边界与状态

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
                    Text("我当时的状态")
                        .font(.subheadline)

                    FlowLayout(spacing: 7, lineSpacing: 8) {
                        ForEach(PersonalState.allCases) { state in
                            RecordChoice(
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
                    Label("心里打鼓的话，下面可以勾「回个消息」或去做检测。", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(Palette.warning)
                }
            } label: {
                HStack {
                    Label("边界与当时状态", systemImage: "person.crop.circle.badge.checkmark")
                    Spacer()
                    if draft.boundaryFeeling != .notRecorded {
                        Text(draft.boundaryFeeling.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(draft.boundaryFeeling.needsFollowUp ? Palette.warning : .secondary)
                    }
                }
            }
        } footer: {
            Text("这是你的事后回看，不替代双方当时清醒、明确且持续的同意。")
        }
    }

    // MARK: - 后续处理

    private var followUpSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showFollowUpDetails) {
                FlowLayout(spacing: 7, lineSpacing: 8) {
                    ForEach(availableFollowUps) { kind in
                        RecordChoice(
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
                    Label("要不要跟进", systemImage: "checklist")
                    Spacer()
                    if draft.hasPendingFollowUp {
                        Text("待处理")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.warning)
                    }
                }
            }
        } footer: {
            Text("只保存你主动勾选的事项和日期，不会自动发消息。")
        }
    }

    // MARK: - 组件与状态

    private var selectedLocationName: String {
        if let cityID = draft.cityID, let location = app.location(id: cityID) {
            return location.name
        }
        if let companion {
            return app.locationName(for: companion)
        }
        return "选择地点"
    }

    private func experiencePicker(
        title: String,
        rating: Binding<Int>,
        emojis: [String],
        labels: [String]
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
                    Text("\(rating.wrappedValue) 分 · \(labels[rating.wrappedValue - 1])")
                        .font(.caption).foregroundStyle(.secondary)
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
                            .scaleEffect(rating.wrappedValue == value && !reduceMotion ? 1.16 : 1)
                            .animation(
                                NativeEditorMotion.animation(reduceMotion: reduceMotion),
                                value: rating.wrappedValue
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(value) 分，\(labels[value - 1])")
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
            "部分行为没戴套，具体情况可写在备忘，需要处理的事可以在跟进页勾选。"
        case .noProtection:
            "无套本身不等于风险结论，看具体行为；需要的话下面勾去做检测或咨询。"
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

    private func save() {
        guard canSave else { return }
        draft.cost = parsedCost
        draft.cityID = draft.cityID ?? companion?.cityID
        draft.normalizeForOutcome()
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
