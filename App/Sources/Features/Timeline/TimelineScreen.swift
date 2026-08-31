import SwiftUI

/// 记录页：暧昧聊天、亲密频率、待跟进与完整时间线。
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
        case .chat:
            app.timeline().filter { $0.kind.isConversation }
        case .intimate:
            app.timeline().filter { $0.kind.isIntimate }
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

                if scope == .all || scope == .intimate {
                    Section {
                        barChart
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } header: {
                        Text("近 6 个月约成")
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
                    ForEach(sections, id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.encounters) { encounter in
                                if app.companion(id: encounter.companionID) != nil {
                                    Button {
                                        Haptics.shared.play(.selection)
                                        encounterTarget = encounter
                                    } label: {
                                        EncounterRow(encounter: encounter)
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
            .navigationTitle("记录册")
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
        recordingKind = scope == .chat ? .chat : .intimacy
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
        case .chat:
            conversationStatsGrid
        case .followUp:
            followUpStatsGrid
        case .all, .intimate:
            intimacyStatsGrid
        }
    }

    private var intimacyStatsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    value: "\(app.stats.totalIntimacyCount)",
                    caption: "约成",
                    systemImage: "flame.fill",
                    tint: Palette.accent
                )
                StatTile(
                    value: "\(app.stats.intimaciesThisMonth)",
                    caption: "本月约成",
                    systemImage: "flame.fill",
                    tint: Palette.coral
                )
            }
            GridRow {
                StatTile(
                    value: "\(app.stats.pendingFollowUpCount)",
                    caption: "待跟进",
                    systemImage: "checklist",
                    tint: app.stats.pendingFollowUpCount > 0 ? Palette.warning : Palette.safe
                )
                StatTile(
                    value: app.stats.averageExperience.map { String(format: "%.1f", $0) } ?? "—",
                    caption: "平均感受",
                    systemImage: "face.smiling",
                    tint: Color(red: 0.95, green: 0.62, blue: 0.28)
                )
            }
        }
    }

    private var conversationStatsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    value: "\(conversationRecords.count)",
                    caption: "聊天记录",
                    systemImage: "heart.text.square.fill",
                    tint: Palette.coral
                )
                StatTile(
                    value: "\(conversationRecordsThisMonth)",
                    caption: "本月记录",
                    systemImage: "calendar",
                    tint: Palette.accent
                )
            }
            GridRow {
                StatTile(
                    value: "\(explicitResponseRecordedCount)",
                    caption: "明确回应已记",
                    systemImage: "checkmark.bubble.fill",
                    tint: Palette.safe
                )
                StatTile(
                    value: "\(pendingConversationFollowUps)",
                    caption: "暧昧待跟进",
                    systemImage: "checklist",
                    tint: pendingConversationFollowUps > 0 ? Palette.warning : Palette.safe
                )
            }
        }
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

    private var conversationRecords: [Encounter] {
        app.encounters.filter { $0.kind.isConversation }
    }

    private var conversationRecordsThisMonth: Int {
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? .distantPast
        return conversationRecords.filter { $0.date >= start }.count
    }

    private var explicitResponseRecordedCount: Int {
        conversationRecords.filter { $0.explicitContentComfort != .notRecorded }.count
    }

    private var pendingConversationFollowUps: Int {
        app.pendingFollowUps.filter { $0.kind.isConversation }.count
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
        let data = monthlyIntimacyCounts
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("共 \(data.reduce(0) { $0 + $1.count }) 次约成")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if app.stats.intimaciesThisMonth > 0 {
                    Text("本月套记了 \(app.stats.safetyRecordedThisMonth) / \(app.stats.intimaciesThisMonth)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Text("\(item.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(item.count > 0 ? Palette.accent : .secondary.opacity(0.5))
                            .contentTransition(.numericText())

                        Capsule(style: .continuous)
                            .fill(
                                item.count > 0
                                    ? AnyShapeStyle(Palette.accent.gradient)
                                    : AnyShapeStyle(Color.secondary.opacity(0.12))
                            )
                            .frame(height: max(4, CGFloat(item.count) * 12))

                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120, alignment: .bottom)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: data.map(\.count))
        }
        .padding(.vertical, 6)
    }

    private var monthlyIntimacyCounts: [(label: String, count: Int)] {
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
                return (labelFormatter.string(from: month), 0)
            }
            let count = app.encounters.filter {
                $0.kind.isIntimate && $0.date >= interval.start && $0.date < interval.end
            }.count
            return (labelFormatter.string(from: month), count)
        }
    }

    private var displayedSections: [(title: String, encounters: [Encounter])] {
        if scope == .followUp {
            return displayedEncounters.isEmpty ? [] : [("待跟进", displayedEncounters)]
        }

        let calendar = Calendar.current
        let formatter = DateFormatter.monthTitle
        var order: [String] = []
        var grouped: [String: [Encounter]] = [:]

        for encounter in displayedEncounters {
            let start = calendar.dateInterval(of: .month, for: encounter.date)?.start ?? encounter.date
            let key = formatter.string(from: start)
            if grouped[key] == nil {
                grouped[key] = []
                order.append(key)
            }
            grouped[key]?.append(encounter)
        }

        return order.map { ($0, grouped[$0] ?? []) }
    }
}

private enum RecordScope: String, CaseIterable, Identifiable {
    case all
    case chat
    case intimate
    case followUp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .chat: "聊天"
        case .intimate: "约成"
        case .followUp: "跟进"
        }
    }

    var emptySymbol: String {
        switch self {
        case .all: "clock.arrow.circlepath"
        case .chat: "message.fill"
        case .intimate: "flame"
        case .followUp: "checkmark.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "记录册还是空的"
        case .chat: "还没记下聊天"
        case .intimate: "还没约成过"
        case .followUp: "没有待办"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: "约成、过夜、留照片，一页页写在这本记录册里。"
        case .chat: "记下她说可以的尺度，别靠回复速度瞎猜。"
        case .intimate: "做了什么、有没有戴套、爽不爽，以后都能翻到。"
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
        return app.currentCompanions.filter { companion in
            q.isEmpty
                || companion.displayName.lowercased().contains(q)
                || app.cityName(for: companion).contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "person.crop.circle.badge.questionmark",
                        title: "没有匹配的对象",
                        message: "换一个代号或城市试试，或先添加当前对象。"
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
            .searchable(text: $query, prompt: "代号 / 城市")
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
