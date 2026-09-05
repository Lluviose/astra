import SwiftUI

/// 名册：还在推进的人。上过床的另有后宫图鉴，这里不重复陈列。
struct RosterScreen: View {

    @Environment(AppState.self) private var app

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var flow = RecordingFlow()
    @State private var showFilter = false
    @State private var isSearching = false
    @State private var pendingDeletion: Companion?

    var body: some View {
        Group {
                if app.companions.isEmpty {
                    EmptyStateView(
                        symbol: "person.2",
                        title: "从一个代号开始",
                        message: "把重要的人和相处细节放在一起，资料可以慢慢补充。",
                        actionTitle: "新建人物",
                        action: { flow.beginAddingCompanion(app: app) }
                    )
                } else {
                    rosterList
                }
            }
            .background(Palette.background)
            .navigationTitle("名册")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                CompanionDetailView(companionID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("排序", selection: app.settingsBinding(\.rosterSort)) {
                            ForEach(RosterSort.allCases) { sort in
                                Label(sort.label, systemImage: sort.symbolName).tag(sort)
                            }
                        }
                        Picker("分组", selection: app.settingsBinding(\.rosterGrouping)) {
                            ForEach(RosterGrouping.allCases) { grouping in
                                Text(grouping.label).tag(grouping)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("排序与分组")
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        app.toggleNamesRevealed()
                    } label: {
                        Image(systemName: app.namesRevealed ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(app.namesRevealed ? "隐藏代号" : "显示代号")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.shared.play(.lightTap)
                        showFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle\(app.filter.activeConditionCount > 0 ? ".fill" : "")")
                    }
                    .accessibilityLabel("筛选，\(app.filter.activeConditionCount) 项生效")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        flow.beginAddingCompanion(app: app)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建人物")
                }
            }
            .searchable(text: Binding(
                get: { app.searchText },
                set: { app.searchText = $0 }
            ), isPresented: $isSearching, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索代号、标签或地点")
            .autocorrectionDisabled()
        .recordingFlowSheets(flow)
        .sheet(isPresented: $showFilter) {
            RosterFilterSheet()
        }
        .confirmationDialog(
            "删除这条档案？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除她和全部记录", role: .destructive) {
                guard let companion = pendingDeletion else { return }
                pendingDeletion = nil
                app.delete(companionID: companion.id)
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("约过的记录和照片也会一起删掉，回不来。")
        }
    }

    private var rosterList: some View {
        List {
            if app.searchText.isEmpty, app.filter.isDefault, !isSearching {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text("人物与关系")
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(app.stats.activeCount) 位人物")
                            .font(.caption).foregroundStyle(Palette.secondaryInk)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            if app.filter.activeConditionCount > 0 || !app.searchText.isEmpty {
                Section {
                    HStack {
                        Text("\(app.filter.activeConditionCount) 项筛选 · \(app.rosterSections().reduce(0) { $0 + $1.companions.count }) 位匹配")
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryInk)
                        Spacer()
                        Button("重置", action: resetSearchAndFilter)
                            .accessibilityIdentifier("roster-reset")
                        .frame(minHeight: 44)
                    }
                }
            }

            if !app.needsAttention.isEmpty, app.searchText.isEmpty, app.filter.isDefault {
                Section {
                    ForEach(app.needsAttention) { companion in
                        NavigationLink(value: companion.id) {
                            CompanionRow(companion: companion)
                        }
                        .listRowBackground(Palette.surface)
                    }
                } header: {
                    HStack(spacing: 5) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Palette.accent)
                        Text("到了联系周期")
                    }
                }
            }

            let sections = app.rosterSections()
            if sections.isEmpty {
                Section {
                    EmptyStateView(
                        symbol: "line.3.horizontal.decrease.circle",
                        title: "没有符合条件的人",
                        message: "试试其他代号，或清除当前条件。",
                        actionTitle: "清除搜索与筛选",
                        action: resetSearchAndFilter
                    )
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.companions) { companion in
                            NavigationLink(value: companion.id) {
                                CompanionRow(companion: companion)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    flow.record(.intimacy, for: companion)
                                } label: {
                                    Label("上床了", systemImage: "flame.fill")
                                }
                                .tint(Palette.coral)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    app.togglePin(companion)
                                } label: {
                                    Label(
                                        companion.isPinned ? "取消置顶" : "置顶",
                                        systemImage: companion.isPinned ? "pin.slash" : "pin.fill"
                                    )
                                }
                                .tint(Palette.accent)

                                Button(role: .destructive) {
                                    Haptics.shared.play(.warning)
                                    pendingDeletion = companion
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 5) {
                            if let symbol = section.symbolName {
                                Image(systemName: symbol)
                                    .foregroundStyle(section.stage?.tint ?? Color.secondary)
                            }
                            Text(section.title)
                            Spacer()
                            Text("\(section.companions.count)")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .astraListStyle()
        .scrollDismissesKeyboard(.interactively)
        .listRowSpacing(2)
        .haptic(.selection, trigger: app.filter.activeConditionCount)
    }

    private func resetSearchAndFilter() {
        app.searchText = ""
        app.resetFilter()
        isSearching = false
    }


}

// MARK: - 筛选面板

struct RosterFilterSheet: View {

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(RelationStage.allCases, id: \.self) { stage in
                            GlassChip(
                                title: stage.label,
                                systemImage: stage.symbolName,
                                isOn: app.filter.stages.contains(stage),
                                tint: stage.tint,
                                compact: true
                            ) {
                                app.mutateFilter { $0.toggle(stage: stage) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("关系状态")
                }

                Section("其他条件") {
                    Picker("综合评分", selection: app.filterBinding(\.minRating)) {
                        Text("不限").tag(0)
                        ForEach(1...5, id: \.self) { threshold in
                            Text("\(threshold * 20) 分及以上").tag(threshold)
                        }
                    }
                    Toggle("只看到了联系周期的", isOn: app.filterBinding(\.needsContactOnly))
                    Toggle("包含已归档", isOn: app.filterBinding(\.includeArchived))

                }

                Section {
                    let locations = app.buckets.map(\.city)
                    if locations.isEmpty {
                        Text("还没有记录地点")
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(locations) { location in
                                GlassChip(
                                    title: location.name,
                                    systemImage: location.isCountry ? "globe" : "mappin",
                                    isOn: app.filter.cityIDs.contains(location.id),
                                    tint: Palette.accent,
                                    compact: true
                                ) {
                                    app.mutateFilter { $0.toggle(cityID: location.id) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("地点")
                }

                Section {
                    let tags = app.usedTags
                    if tags.isEmpty {
                        Text("还没有标签")
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                GlassChip(
                                    title: tag,
                                    isOn: app.filter.tags.contains(tag),
                                    tint: Color.secondary,
                                    compact: true
                                ) {
                                    app.mutateFilter { $0.toggle(tag: tag) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("标签")
                }

                Section {
                    Button("清除全部筛选") {
                        app.resetFilter()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(app.filter.isDefault)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
