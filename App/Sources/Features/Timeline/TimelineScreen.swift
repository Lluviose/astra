import SwiftUI

/// The journal is the starting point: entries, precise filters and follow-up actions.
struct TimelineScreen: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var flow = RecordingFlow()
    @State private var filter = JournalFilter()
    @State private var isSearching = false
    @State private var showFilters = false
    @State private var editing: Encounter?
    @State private var deleting: Encounter?
    @State private var completedFollowUp: Encounter?

    private var records: [Encounter] {
        filter.apply(to: app.encounters, companions: app.companions, locationName: { app.locationName(for: $0) })
    }
    private var days: [Date] {
        Array(Set(records.map { Calendar.current.startOfDay(for: $0.date) })).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            List {
                if !isSearching, !filter.isActive {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(Date().formatted(.dateTime.year().month(.wide)))
                                .font(.caption.monospaced()).tracking(2)
                                .foregroundStyle(Palette.accent)
                            Text("你的战绩")
                                .font(.system(.largeTitle, design: .serif))
                                .foregroundStyle(Palette.ink)
                                .accessibilityAddTraits(.isHeader)
                            Text(app.encounters.isEmpty ? "从一个代号，开始第一个片刻。" : "\(app.encounters.count) 篇记录，每个片刻，都值得回味。")
                                .font(.subheadline).foregroundStyle(Palette.secondaryInk)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                if !app.encounters.isEmpty {
                    Section {
                        Picker("记录范围", selection: $filter.scope) {
                            ForEach(JournalScope.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("journal-scope")
                    }
                }

                if filter.isActive {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(records.count) 篇匹配").font(.subheadline.weight(.medium))
                                Text(filterSummary).font(.caption).foregroundStyle(Palette.secondaryInk)
                            }
                            Spacer()
                            Button("重置") { resetFilters() }
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("journal-reset")
                        }
                    }
                } else if !app.pendingFollowUps.isEmpty {
                    Section {
                        Button { filter.scope = .pending } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checklist").foregroundStyle(Palette.accent)
                                Text("待跟进")
                                Spacer()
                                Text("\(app.pendingFollowUps.count) 项").foregroundStyle(Palette.secondaryInk)
                                ChevronHint()
                            }
                            .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("journal-follow-ups")
                    }
                }

                if records.isEmpty {
                    Section {
                        if filter.isActive {
                            EmptyStateView(symbol: "text.magnifyingglass", title: "没有符合条件的记录",
                                           message: "可以调整时间、人物或关键词。",
                                           actionTitle: "清除条件", action: resetFilters)
                        } else {
                            VStack(alignment: .leading, spacing: 24) {
                                AstraMark(color: Palette.accent)
                                Text("不用一次记完整。")
                                    .font(.system(.title2, design: .serif))
                                Text("先写下人物、时间和一段感受。照片、地点和其他细节，都可以以后补充。")
                                    .font(.body).foregroundStyle(Palette.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button { beginRecording() } label: {
                                    PrimaryActionLabel(title: "写第一篇", systemImage: "square.and.pencil")
                                }
                                .buttonStyle(HapticButtonStyle())
                                .accessibilityIdentifier("first-record")
                            }
                            .padding(.vertical, 20)
                        }
                    }
                } else {
                    ForEach(days, id: \.self) { day in
                        Section(Format.timelineDay(day)) {
                            ForEach(records.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { record in
                                recordRow(record)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped).astraListStyle()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("战绩")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter.query, isPresented: $isSearching,
                        placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索人物、地点或片刻")
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SettingsButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: filter.period != .all || filter.companionID != nil
                              ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("筛选时间与人物")
                    .accessibilityIdentifier("journal-filter")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { beginRecording() } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("写一篇记录")
                        .accessibilityIdentifier("new-record")
                }
            }
            .navigationDestination(for: UUID.self) { CompanionDetailView(companionID: $0) }
        }
        .recordingFlowSheets(flow)
        .sheet(item: $editing) { EncounterEditor(encounter: $0) }
        .sheet(isPresented: $showFilters) { filterSheet }
        .confirmationDialog("删除这篇记录？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                if let record = deleting { app.delete(encounterID: record.id) }
                deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        } message: { Text("仅由这篇记录引用的照片也会删除。") }
        .safeAreaInset(edge: .bottom) {
            if let completed = completedFollowUp {
                HStack {
                    Label("跟进已完成", systemImage: "checkmark.circle")
                    Spacer()
                    Button("撤销") {
                        app.setFollowUpDone(false, for: completed.id)
                        completedFollowUp = nil
                    }
                    .accessibilityIdentifier("undo-follow-up")
                }
                .font(.subheadline).padding(16)
                .background(Palette.surface)
            }
        }
    }

    private func recordRow(_ record: Encounter) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if filter.scope == .pending {
                Button {
                    app.setFollowUpDone(true, for: record.id)
                    completedFollowUp = record
                } label: {
                    Image(systemName: "circle").font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("完成这条跟进")
                .accessibilityIdentifier("complete-follow-up-\(record.id.uuidString)")
            }
            Button { editing = record } label: {
                if filter.scope == .pending { FollowUpRow(encounter: record) }
                else { EncounterRow(encounter: record, showTime: true) }
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deleting = record } label: { Label("删除", systemImage: "trash") }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if record.hasPendingFollowUp {
                Button {
                    app.setFollowUpDone(true, for: record.id)
                    completedFollowUp = record
                } label: { Label("完成跟进", systemImage: "checkmark") }
                .tint(Palette.safe)
            }
        }
        .listRowBackground(Palette.surface)
    }

    private var filterSummary: String {
        var parts = [filter.period.label, filter.scope.label]
        if let id = filter.companionID, let person = app.companion(id: id) {
            parts.append(app.namesRevealed ? person.displayName : "已选人物")
        }
        return parts.joined(separator: " · ")
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    Picker("时间范围", selection: $filter.period) {
                        ForEach(RecordPeriod.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.inline)
                }
                Section("人物") {
                    Picker("人物", selection: $filter.companionID) {
                        Text("全部人物").tag(UUID?.none)
                        ForEach(app.companions) { person in
                            Text(app.namesRevealed ? person.displayName : "已隐藏人物")
                                .tag(Optional(person.id))
                        }
                    }
                }
                Button("清除全部条件") { resetFilters(); showFilters = false }
            }
            .astraListStyle()
            .navigationTitle("筛选记录").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showFilters = false }.accessibilityIdentifier("journal-filter-done")
                }
            }
        }
    }

    private func resetFilters() { filter = JournalFilter(); isSearching = false }
    private func beginRecording() {
        flow.begin(kind: filter.scope == .other ? .missed : .intimacy, app: app)
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
    var onCreate: (() -> Void)? = nil

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
                    || matchingLocationIDs.contains(companion.cityID)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if let onCreate {
                    Section {
                        Button {
                            onCreate()
                            dismiss()
                        } label: {
                            Label("新建人物并记录", systemImage: "person.badge.plus")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("picker-new-person")
                    }
                }
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "person.crop.circle.badge.questionmark",
                        title: "没有匹配的人",
                        message: "换个关键词，或新建一个人物继续记录。"
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
        .astraListStyle()
            .navigationTitle("这次和谁")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "代号 / 地点")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
