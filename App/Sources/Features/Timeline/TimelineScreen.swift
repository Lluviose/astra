import SwiftUI

/// 按天呈现「上床了 / 没上床」结果、地点与后续事项。
struct TimelineScreen: View {

    @Environment(AppState.self) private var app

    @State private var flow = RecordingFlow()
    @State private var path = NavigationPath()
    @State private var encounterTarget: Encounter?
    @State private var scope: RecordScope = .all
    @State private var query = ""

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var displayedEncounters: [Encounter] {
        let base: [Encounter]
        switch scope {
        case .all:
            base = app.timeline()
        case .hookedUp:
            base = app.timeline().filter { $0.kind.isIntimate }
        case .missed:
            base = app.timeline().filter { $0.kind.isMissed }
        case .followUp:
            base = app.pendingFollowUps
        }
        guard !normalizedQuery.isEmpty else { return base }
        return base.filter(matchesQuery)
    }

    private func matchesQuery(_ encounter: Encounter) -> Bool {
        let q = normalizedQuery
        if encounter.place.lowercased().contains(q) { return true }
        if encounter.note.lowercased().contains(q) { return true }
        if encounter.venueCategory != .notRecorded, encounter.venueCategory.label.lowercased().contains(q) { return true }
        if encounter.missedSummary.lowercased().contains(q) { return true }
        if encounter.followUpNote.lowercased().contains(q) { return true }
        if app.locationName(for: encounter).lowercased().contains(q) { return true }
        if let companion = app.companion(id: encounter.companionID),
           companion.displayName.lowercased().contains(q) {
            return true
        }
        if encounter.activities.contains(where: { $0.label.lowercased().contains(q) }) { return true }
        if encounter.climaxDetails.contains(where: { $0.label.lowercased().contains(q) }) { return true }
        if encounter.rhythmSummary.lowercased().contains(q) { return true }
        return false
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if normalizedQuery.isEmpty {
                    Section {
                        statsGrid
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    Picker("显示范围", selection: $scope) {
                        ForEach(RecordScope.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if normalizedQuery.isEmpty, scope == .all, !app.pendingFollowUps.isEmpty {
                    Section {
                        ForEach(app.pendingFollowUps.prefix(3)) { encounter in
                            Button {
                                Haptics.shared.play(.selection)
                                encounterTarget = encounter
                            } label: {
                                FollowUpRow(encounter: encounter)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label("接下来", systemImage: "checklist")
                    } footer: {
                        Text("点开记录就能改日期或勾完成。")
                    }
                }

                if normalizedQuery.isEmpty, scope == .all || scope == .hookedUp {
                    Section {
                        OutcomeMonthChart(points: EncounterInsights.monthSeries(encounters: app.encounters, monthCount: 6))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        NavigationLink {
                            InsightsScreen()
                        } label: {
                            Label("看完整战绩统计", systemImage: "chart.bar.xaxis")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                        }
                    } header: {
                        Text("近 6 个月")
                    }
                }

                let sections = displayedSections
                if sections.isEmpty {
                    Section {
                        if normalizedQuery.isEmpty {
                            EmptyStateView(
                                symbol: scope.emptySymbol,
                                title: scope.emptyTitle,
                                message: scope.emptyMessage,
                                actionTitle: scope == .followUp ? nil : "记一笔",
                                action: scope == .followUp ? nil : { beginRecording() }
                            )
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                } else {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.encounters) { encounter in
                                if app.companion(id: encounter.companionID) != nil {
                                    Button {
                                        Haptics.shared.play(.selection)
                                        encounterTarget = encounter
                                    } label: {
                                        EncounterRow(encounter: encounter, showTime: true)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            app.delete(encounterID: encounter.id)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            path.append(encounter.companionID)
                                        } label: {
                                            Label("档案", systemImage: "book.pages.fill")
                                        }
                                        .tint(Palette.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("时间线")
            .navigationDestination(for: UUID.self) { id in
                CompanionDetailView(companionID: id)
            }
            .searchable(text: $query, prompt: "代号 / 地点 / 备注 / 玩法")
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        beginRecording()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("记一笔")
                }
            }
        }
        .recordingFlowSheets(flow)
        .sheet(item: $encounterTarget) { encounter in
            EncounterEditor(encounter: encounter)
        }
    }

    private func beginRecording() {
        flow.begin(kind: scope == .missed ? .missed : .intimacy, app: app)
    }

    // MARK: 统计

    @ViewBuilder
    private var statsGrid: some View {
        switch scope {
        case .followUp:
            followUpStatsGrid
        case .all, .hookedUp, .missed:
            outcomeStatsGrid
        }
    }

    private var outcomeStatsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    value: "\(app.stats.totalIntimacyCount)",
                    caption: "上床",
                    systemImage: "flame.fill",
                    tint: Palette.accent
                )
                StatTile(
                    value: "\(app.stats.missedCount)",
                    caption: "没上床",
                    systemImage: "xmark.circle.fill",
                    tint: EncounterKind.missed.tint
                )
            }
            GridRow {
                StatTile(
                    value: "\(app.stats.cityCount)",
                    caption: "涉及地点",
                    systemImage: "map.fill",
                    tint: Palette.safe
                )
                StatTile(
                    value: hookupRateText,
                    caption: "上床率",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: Color(red: 0.95, green: 0.62, blue: 0.28)
                )
            }
        }
    }

    private var hookupRateText: String {
        guard let rate = app.insights.hookupRate else { return "—" }
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }

    private var followUpStatsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    value: "\(app.pendingFollowUps.count)",
                    caption: "全部待跟进",
                    systemImage: "checklist",
                    tint: Palette.warning
                )
                StatTile(
                    value: "\(overdueFollowUpCount)",
                    caption: "已超期",
                    systemImage: "exclamationmark.circle.fill",
                    tint: overdueFollowUpCount > 0 ? Palette.coral : Palette.safe
                )
            }
            GridRow {
                StatTile(
                    value: "\(todayFollowUpCount)",
                    caption: "今天",
                    systemImage: "calendar.circle.fill",
                    tint: Palette.accent
                )
                StatTile(
                    value: "\(unscheduledFollowUpCount)",
                    caption: "未设日期",
                    systemImage: "calendar",
                    tint: .secondary
                )
            }
        }
    }

    private var overdueFollowUpCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return app.pendingFollowUps.filter {
            guard let due = $0.followUpDate else { return false }
            return Calendar.current.startOfDay(for: due) < today
        }.count
    }

    private var todayFollowUpCount: Int {
        app.pendingFollowUps.filter {
            guard let due = $0.followUpDate else { return false }
            return Calendar.current.isDateInToday(due)
        }.count
    }

    private var unscheduledFollowUpCount: Int {
        app.pendingFollowUps.filter { $0.followUpDate == nil }.count
    }

    private var displayedSections: [RecordTimelineSection] {
        if scope == .followUp {
            return displayedEncounters.isEmpty
                ? []
                : [RecordTimelineSection(id: "follow-up", title: "待跟进", encounters: displayedEncounters)]
        }

        let calendar = Calendar.current
        var order: [Date] = []
        var grouped: [Date: [Encounter]] = [:]

        for encounter in displayedEncounters {
            let day = calendar.startOfDay(for: encounter.date)
            if grouped[day] == nil {
                grouped[day] = []
                order.append(day)
            }
            grouped[day]?.append(encounter)
        }

        return order.map { day in
            RecordTimelineSection(
                id: String(day.timeIntervalSinceReferenceDate),
                title: Format.timelineDay(day),
                encounters: grouped[day] ?? []
            )
        }
    }
}

private struct RecordTimelineSection: Identifiable {
    let id: String
    let title: String
    let encounters: [Encounter]
}

private enum RecordScope: String, CaseIterable, Identifiable {
    case all
    case hookedUp
    case missed
    case followUp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .hookedUp: "上床"
        case .missed: "没上"
        case .followUp: "跟进"
        }
    }

    var emptySymbol: String {
        switch self {
        case .all: "clock.arrow.circlepath"
        case .hookedUp: "flame"
        case .missed: "xmark.circle"
        case .followUp: "checkmark.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "时间线还是空的"
        case .hookedUp: "还没上床过"
        case .missed: "还没有没上床的记录"
        case .followUp: "没有待办"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: "每次上床或没上床，都按日期和地点排在这里。"
        case .hookedUp: "做了什么、有没有戴套、爽不爽，以后都能翻到。"
        case .missed: "没成也记下时间和地点，方便回看自己的猎场轨迹。"
        case .followUp: "只有你自己勾过、还没做完的才会出现。"
        }
    }
}

/// 记录页和首页共用的事后任务摘要。
struct FollowUpRow: View {
    let encounter: Encounter

    @Environment(AppState.self) private var app

    private var companion: Companion? { app.companion(id: encounter.companionID) }

    private var isOverdue: Bool {
        guard let due = encounter.followUpDate else { return false }
        return Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isOverdue ? Palette.coral : Palette.warning).opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "checklist")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isOverdue ? Palette.coral : Palette.warning)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if let companion {
                        MaskedName(
                            name: companion.displayName,
                            revealed: app.namesRevealed,
                            font: .subheadline.weight(.semibold)
                        )
                    }
                    Text(encounter.followUpSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(Format.followUpDue(encounter.followUpDate))
                        .foregroundStyle(isOverdue ? Palette.coral : .secondary)
                    if !encounter.followUpNote.isEmpty {
                        Text("· \(encounter.followUpNote)")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)
            ChevronHint()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 选人面板

struct CompanionPickerSheet: View {

    let onSelect: (Companion) -> Void
    let onAdd: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var filtered: [Companion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingLocationIDs = Set(
            app.catalog.search(q, limit: app.catalog.locations.count).map(\.id)
        )
        return app.currentCompanions
            .sorted { app.lastContact(for: $0) > app.lastContact(for: $1) }
            .filter { companion in
                q.isEmpty
                    || companion.displayName.lowercased().contains(q)
                    || companion.contactNote.lowercased().contains(q)
                    || companion.tags.contains { $0.lowercased().contains(q) }
                    || matchingLocationIDs.contains(companion.cityID)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onAdd()
                        dismiss()
                    } label: {
                        Label("新增人物，接着记这次", systemImage: "person.badge.plus")
                    }
                }
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "person.crop.circle.badge.questionmark",
                        title: "没有匹配的人",
                        message: "换个关键词，或点上方新增人物。"
                    )
                } else {
                    ForEach(filtered) { companion in
                        Button {
                            Haptics.shared.play(.selection)
                            onSelect(companion)
                            dismiss()
                        } label: {
                            CompanionRow(companion: companion)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("记谁？")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "代号 / 联系方式 / 标签 / 地点")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
