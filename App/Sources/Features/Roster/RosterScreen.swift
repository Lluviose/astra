import SwiftUI

struct RosterScreen: View {

    @Environment(AppState.self) private var app

    @State private var showFilter = false
    @State private var isPickingCity = false
    @State private var editorTarget: Companion?

    var body: some View {
        NavigationStack {
            Group {
                if app.companions.isEmpty {
                    EmptyStateView(
                        symbol: "person.2",
                        title: "名单还是空的",
                        message: "添加第一个人的档案后，她会出现在这里，也会点亮地图。",
                        actionTitle: "添加",
                        action: { isPickingCity = true }
                    )
                } else {
                    rosterList
                }
            }
            .navigationTitle("名单")
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
                    .accessibilityLabel(app.namesRevealed ? "隐藏名字" : "显示名字")
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
                        Haptics.shared.play(.lightTap)
                        isPickingCity = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加")
                }
            }
            .searchable(text: Binding(
                get: { app.searchText },
                set: { app.searchText = $0 }
            ), prompt: "名字 / 标签 / 城市")
            .autocorrectionDisabled()
        }
        .sheet(isPresented: $showFilter) {
            RosterFilterSheet()
        }
        .sheet(isPresented: $isPickingCity) {
            CityPickerSheet(title: "在哪座城市认识的？") { city in
                var draft = app.makeDraftCompanion(cityID: city.id)
                draft.cityID = city.id
                editorTarget = draft
            }
        }
        .sheet(item: $editorTarget) { companion in
            CompanionEditor(companion: companion)
        }
    }

    private var rosterList: some View {
        List {
            if !app.needsAttention.isEmpty {
                Section {
                    ForEach(app.needsAttention) { companion in
                        NavigationLink(value: companion.id) {
                            CompanionRow(companion: companion)
                        }
                        .listRowBackground(
                            Palette.accent.opacity(0.06)
                        )
                    }
                } header: {
                    HStack(spacing: 5) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Palette.accent)
                        Text("该联系了")
                    }
                }
            }

            let sections = app.rosterSections()
            if sections.isEmpty {
                Section {
                    EmptyStateView(
                        symbol: "line.3.horizontal.decrease.circle",
                        title: "没有符合条件的人",
                        message: "试试放宽筛选条件，或清空搜索词。"
                    )
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.companions) { companion in
                            NavigationLink(value: companion.id) {
                                CompanionRow(companion: companion)
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
                                .tint(.orange)

                                Button(role: .destructive) {
                                    Haptics.shared.play(.warning)
                                    app.delete(companionID: companion.id)
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
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .haptic(.selection, trigger: app.filter.activeConditionCount)
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
                    Text("关系阶段")
                }

                Section("其他条件") {
                    Toggle("只看该联系了的人", isOn: app.filterBinding(\.needsContactOnly))
                    Toggle("包含已归档", isOn: app.filterBinding(\.includeArchived))

                    HStack {
                        Text("心动指数 ≥")
                        Spacer()
                        Stepper(
                            app.filter.minRating == 0 ? "不限" : "\(app.filter.minRating) 星",
                            value: Binding(
                                get: { app.filter.minRating },
                                set: { newValue in
                                    var clamped = min(max(newValue, 0), 5)
                                    if clamped == 5 { clamped = 0 } // 5 星没有筛选意义，视为不限
                                    app.mutateFilter { $0.minRating = clamped }
                                }
                            ),
                            in: 0...5,
                            step: 1
                        )
                    }
                }

                Section {
                    let cities = app.buckets.map(\.city)
                    if cities.isEmpty {
                        Text("还没有记录城市")
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(cities) { city in
                                GlassChip(
                                    title: city.name,
                                    systemImage: "mappin",
                                    isOn: app.filter.cityIDs.contains(city.id),
                                    tint: Palette.accent,
                                    compact: true
                                ) {
                                    app.mutateFilter { $0.toggle(cityID: city.id) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("城市")
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
