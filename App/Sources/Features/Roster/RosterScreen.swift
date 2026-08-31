import SwiftUI

struct RosterScreen: View {

    @Environment(AppState.self) private var app

    @State private var showFilter = false
    @State private var isPickingCity = false
    @State private var editorTarget: Companion?
    @State private var pendingCitySelection: City?
    @State private var pendingDeletion: Companion?

    var body: some View {
        NavigationStack {
            Group {
                if app.companions.isEmpty {
                    EmptyStateView(
                        symbol: "person.2",
                        title: "还没有对象",
                        message: "用代号建一份私密档案，记下相处状态、边界与安全信息。",
                        actionTitle: "添加对象",
                        action: { isPickingCity = true }
                    )
                } else {
                    rosterList
                }
            }
            .navigationTitle("对象")
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
                        Haptics.shared.play(.lightTap)
                        isPickingCity = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加对象")
                }
            }
            .searchable(text: Binding(
                get: { app.searchText },
                set: { app.searchText = $0 }
            ), prompt: "代号 / 标签 / 城市")
            .autocorrectionDisabled()
        }
        .sheet(isPresented: $showFilter) {
            RosterFilterSheet()
        }
        .sheet(isPresented: $isPickingCity, onDismiss: finishCitySelection) {
            CityPickerSheet(title: "常驻或常见面的城市") { city in
                pendingCitySelection = city
            }
        }
        .sheet(item: $editorTarget) { companion in
            CompanionEditor(companion: companion)
        }
        .confirmationDialog(
            "删除这条档案？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除对象及全部记录", role: .destructive) {
                guard let companion = pendingDeletion else { return }
                pendingDeletion = nil
                app.delete(companionID: companion.id)
            }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("与这个对象关联的全部记录也会删除，且无法恢复。")
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
                        Text("到了联系周期")
                    }
                }
            }

            let sections = app.rosterSections()
            if sections.isEmpty {
                Section {
                    EmptyStateView(
                        symbol: "line.3.horizontal.decrease.circle",
                        title: "没有符合条件的对象",
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
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .haptic(.selection, trigger: app.filter.activeConditionCount)
    }

    private func finishCitySelection() {
        guard let city = pendingCitySelection else { return }
        pendingCitySelection = nil
        editorTarget = app.makeDraftCompanion(cityID: city.id)
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
                    Text("相处状态")
                }

                Section("其他条件") {
                    Toggle("只看到了联系周期的对象", isOn: app.filterBinding(\.needsContactOnly))
                    Toggle("包含已归档", isOn: app.filterBinding(\.includeArchived))

                    HStack {
                        Text("默契度 ≥")
                        Spacer()
                        Stepper(
                            app.filter.minRating == 0 ? "不限" : "\(app.filter.minRating) 星",
                            value: Binding(
                                get: { app.filter.minRating },
                                set: { newValue in
                                    app.mutateFilter { $0.minRating = min(max(newValue, 0), 5) }
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
