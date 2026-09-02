import SwiftUI

/// 按天呈现「上床了 / 没上床」结果、地点与后续事项。
struct TimelineScreen: View {

    @Environment(AppState.self) private var app

    @State private var isPickingCompanion = false
    @State private var isPickingCity = false
    @State private var encounterTarget: Encounter?
    @State private var companionEditorTarget: Companion?
    @State private var scope: RecordScope = .all
    @State private var recordingKind: EncounterKind = .intimacy
    @State private var pendingCompanionSelection: Companion?
    @State private var pendingCitySelection: City?
    @State private var recordingCompanionID: UUID?

    private var displayedEncounters: [Encounter] {
        switch scope {
        case .all:
            app.timeline()
        case .hookedUp:
            app.timeline().filter { $0.kind.isIntimate }
        case .missed:
            app.timeline().filter { $0.kind.isMissed }
        case .followUp:
            app.pendingFollowUps
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsGrid
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    Picker("显示范围", selection: $scope) {
                        ForEach(RecordScope.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if scope == .all, !app.pendingFollowUps.isEmpty {
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
                        Text("点开记录即可修改日期或标记完成。")
                    }
                }

                if scope == .all || scope == .hookedUp {
                    Section {
                        barChart
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } header: {
                        Text("近 6 个月结果")
                    }
                }

                let sections = displayedSections
                if sections.isEmpty {
                    Section {
                        EmptyStateView(
                            symbol: scope.emptySymbol,
                            title: scope.emptyTitle,
                            message: scope.emptyMessage,
                            actionTitle: scope == .followUp ? nil : "记一笔",
                            action: scope == .followUp ? nil : { beginRecording() }
                        )
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
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("时间线")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.shared.play(.lightTap)
                        beginRecording()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("记一笔")
                }
            }
        }
        .sheet(isPresented: $isPickingCompanion, onDismiss: finishCompanionSelection) {
            CompanionPickerSheet { companion in
                pendingCompanionSelection = companion
            }
        }
        .sheet(item: $encounterTarget) { encounter in
            EncounterEditor(encounter: encounter)
        }
        .sheet(isPresented: $isPickingCity, onDismiss: finishCitySelection) {
            CityPickerSheet(title: "先添加记录对象") { city in
                pendingCitySelection = city
            }
        }
        .sheet(item: $companionEditorTarget, onDismiss: finishCompanionEditor) { companion in
            CompanionEditor(companion: companion)
        }
    }

    private func beginRecording() {
        recordingKind = scope == .missed ? .missed : .intimacy
        pendingCompanionSelection = nil

        if app.currentCompanions.isEmpty {
            pendingCitySelection = nil
            recordingCompanionID = nil
            isPickingCity = true
        } else {
            isPickingCompanion = true
        }
    }

    private func finishCompanionSelection() {
        guard let companion = pendingCompanionSelection else { return }
        pendingCompanionSelection = nil
        encounterTarget = Encounter(
            companionID: companion.id,
            kind: recordingKind,
            cityID: companion.cityID
        )
    }

    private func finishCitySelection() {
        guard let city = pendingCitySelection else {
            recordingCompanionID = nil
            return
        }
        pendingCitySelection = nil
        let draft = app.makeDraftCompanion(cityID: city.id)
        recordingCompanionID = draft.id
        companionEditorTarget = draft
    }

    private func finishCompanionEditor() {
        defer { recordingCompanionID = nil }
        guard let companionID = recordingCompanionID,
              let companion = app.companion(id: companionID)
        else { return }

        encounterTarget = Encounter(
            companionID: companion.id,
            kind: recordingKind,
            cityID: companion.cityID
        )
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
                    tint: Color(red: 0.30, green: 0.70, blue: 0.56)
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
        let total = app.stats.totalIntimacyCount + app.stats.missedCount
        guard total > 0 else { return "—" }
        let rate = Double(app.stats.totalIntimacyCount) / Double(total)
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

    // MARK: 近 6 个月柱状图（纯 SwiftUI，无第三方库）

    private var barChart: some View {
        let data = monthlyOutcomeCounts
        let hookupTotal = data.reduce(0) { $0 + $1.hookedUp }
        let missedTotal = data.reduce(0) { $0 + $1.missed }
        let peak = max(1, data.flatMap { [$0.hookedUp, $0.missed] }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("上床 \(hookupTotal)", systemImage: "flame.fill")
                    .foregroundStyle(EncounterKind.intimacy.tint)
                Spacer()
                Label("没上床 \(missedTotal)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(EncounterKind.missed.tint)
            }
            .font(.caption.weight(.semibold))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Text("\(item.hookedUp)/\(item.missed)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(
                                item.hookedUp + item.missed > 0
                                    ? Color.secondary
                                    : Color.secondary.opacity(0.45)
                            )
                            .contentTransition(.numericText())

                        HStack(alignment: .bottom, spacing: 3) {
                            Capsule(style: .continuous)
                                .fill(EncounterKind.intimacy.tint.gradient)
                                .frame(
                                    width: 8,
                                    height: item.hookedUp > 0
                                        ? max(10, CGFloat(item.hookedUp) / CGFloat(peak) * 70)
                                        : 4
                                )
                                .opacity(item.hookedUp > 0 ? 1 : 0.16)

                            Capsule(style: .continuous)
                                .fill(EncounterKind.missed.tint.gradient)
                                .frame(
                                    width: 8,
                                    height: item.missed > 0
                                        ? max(10, CGFloat(item.missed) / CGFloat(peak) * 70)
                                        : 4
                                )
                                .opacity(item.missed > 0 ? 1 : 0.16)
                        }
                        .frame(height: 74, alignment: .bottom)

                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 112, alignment: .bottom)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8),
                value: data.map { $0.hookedUp + $0.missed }
            )
        }
        .padding(.vertical, 6)
    }

    private var monthlyOutcomeCounts: [(label: String, hookedUp: Int, missed: Int)] {
        let calendar = Calendar.current
        var months: [Date] = []
        guard let now = calendar.dateInterval(of: .month, for: Date())?.start else { return [] }
        for offset in stride(from: -5, through: 0, by: 1) {
            if let month = calendar.date(byAdding: .month, value: offset, to: now) {
                months.append(month)
            }
        }

        let labelFormatter = DateFormatter()
        labelFormatter.setLocalizedDateFormatFromTemplate("MMM")

        return months.map { month in
            guard let interval = calendar.dateInterval(of: .month, for: month) else {
                return (labelFormatter.string(from: month), 0, 0)
            }
            let records = app.encounters.filter {
                $0.date >= interval.start && $0.date < interval.end
            }.count
            let hookedUp = app.encounters.filter {
                $0.kind.isIntimate && $0.date >= interval.start && $0.date < interval.end
            }.count
            return (labelFormatter.string(from: month), hookedUp, records - hookedUp)
        }
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
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 选人面板

struct CompanionPickerSheet: View {

    let onSelect: (Companion) -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var filtered: [Companion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingLocationIDs = Set(
            app.catalog.search(q, limit: app.catalog.locations.count).map(\.id)
        )
        return app.currentCompanions.filter { companion in
            q.isEmpty
                || companion.displayName.lowercased().contains(q)
                || matchingLocationIDs.contains(companion.cityID)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "person.crop.circle.badge.questionmark",
                        title: "没有匹配的对象",
                        message: "换一个代号或地点试试，或先添加当前对象。"
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
            .navigationTitle("记录谁？")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "代号 / 地点")
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
