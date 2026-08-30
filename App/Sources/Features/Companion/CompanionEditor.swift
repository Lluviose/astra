import SwiftUI

// MARK: - 城市选择（编辑表单里的内嵌路由）

private struct EditorCityPickerRoute: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @Binding var cityID: String

    private var selectedCity: City? { app.city(id: cityID) }

    var body: some View {
        List {
            if query.isEmpty, let selectedCity {
                Section("当前选择") {
                    cityRow(selectedCity, isSelected: true)
                }
            }
            if query.isEmpty {
                let known = app.buckets.map(\.city)
                if !known.isEmpty {
                    Section("已有记录") {
                        ForEach(known) { cityRow($0) }
                    }
                }
                ForEach(groupedCities, id: \.0) { tier, cities in
                    Section(tier.label) {
                        ForEach(cities) { cityRow($0) }
                    }
                }
            } else {
                Section("搜索结果") {
                    ForEach(app.catalog.search(query)) { cityRow($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "城市 / 拼音 / 首字母")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle("选择城市")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if !query.isEmpty, app.catalog.search(query).isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private var groupedCities: [(CityTier, [City])] {
        let grouped = Dictionary(grouping: app.catalog.cities, by: \.tier)
        return CityTier.allCases.compactMap { tier in
            guard let cities = grouped[tier], !cities.isEmpty else { return nil }
            return (tier, cities.sorted { $0.pinyin < $1.pinyin })
        }
    }

    private func cityRow(_ city: City, isSelected: Bool = false) -> some View {
        Button {
            Haptics.shared.play(.cityFocus)
            cityID = city.id
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                    Text("\(city.shortProvince) · \(city.pinyin)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected || city.id == cityID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 档案编辑器

struct CompanionEditor: View {

    let initial: Companion

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Companion
    @State private var showDeleteConfirm = false
    @State private var isPickingCity = false
    @State private var newTag = ""
    @State private var showAddTagDialog = false
    @State private var showUnsavedAlert = false

    private var isNew: Bool { !app.companions.contains { $0.id == initial.id } }

    init(companion: Companion) {
        self.initial = companion
        _draft = State(initialValue: companion)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                statusSection
                citySection
                tagsSection
                detailSection
                if !isNew {
                    dangerSection
                }
            }
            .navigationTitle(isNew ? "添加" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        if isNew {
                            dismiss()
                        } else {
                            showUnsavedAlert = true
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .tint(Palette.accent)
                }
            }
            .navigationDestination(isPresented: $isPickingCity) {
                EditorCityPickerRoute(cityID: $draft.cityID)
            }
            .alert("放弃未保存的修改？", isPresented: $showUnsavedAlert) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { dismiss() }
            } message: {
                Text("关闭后，本次修改不会保留。")
            }
            .alert("添加标签", isPresented: $showAddTagDialog) {
                TextField("标签", text: $newTag)
                Button("添加") {
                    let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tag.isEmpty, !draft.tags.contains(tag) {
                        draft.tags.append(tag)
                        Haptics.shared.play(.toggleOn)
                    }
                    newTag = ""
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("确定删除这条档案？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除档案及全部记录", role: .destructive) {
                    app.delete(companionID: initial.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("连同相处记录一起删除，且无法恢复。")
            }
        }
    }

    private func save() {
        app.upsert(draft)
        dismiss()
    }

    // MARK: 基本信息

    private var basicSection: some View {
        Section("基本信息") {
            HStack(spacing: 12) {
                AvatarView(
                    companion: draft,
                    size: 56,
                    showRing: false
                )
                TextField("名字（可留空）", text: $draft.name)
                    .textInputAutocapitalization(.never)
            }

            HStack {
                Text("头像符号")
                Spacer()
                TextField("emoji 或首字", text: $draft.emoji)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 180)
                    .textInputAutocapitalization(.never)
            }

            Picker("年龄", selection: $draft.age) {
                Text("未设置").tag(Int?.none)
                ForEach(18...60, id: \.self) { age in
                    Text("\(age)").tag(Int?.some(age))
                }
            }

            Picker("身高", selection: $draft.heightCM) {
                Text("未设置").tag(Int?.none)
                ForEach(140...200, id: \.self) { cm in
                    Text("\(cm) cm").tag(Int?.some(cm))
                }
            }

            HStack {
                Text("生日")
                Spacer()
                MonthDayMenu(month: $draft.birthdayMonth, day: $draft.birthdayDay)
            }

            TextField("职业", text: $draft.occupation)
        }
    }

    // MARK: 关系状态

    private var statusSection: some View {
        Section("关系状态") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RelationStage.allCases, id: \.self) { stage in
                        Button {
                            Haptics.shared.play(.selection)
                            draft.stage = stage
                        } label: {
                            HStack(spacing: 5) {
                                if draft.stage == stage {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                }
                                Text(stage.label).font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(draft.stage == stage ? .white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if draft.stage == stage {
                                    Capsule().fill(stage.tint.gradient)
                                }
                            }
                            .glassCapsule(interactive: true, shadowRadius: 8)
                        }
                        .buttonStyle(HapticButtonStyle(cue: .selection))
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

            HStack {
                Text("心动指数")
                Spacer()
                RatingPicker(rating: $draft.rating, size: 24)
            }
        }
    }

    // MARK: 城市与认识渠道

    private var citySection: some View {
        Section("城市") {
            Button {
                Haptics.shared.play(.lightTap)
                isPickingCity = true
            } label: {
                HStack {
                    Label(app.cityName(for: draft), systemImage: "mappin.circle.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("怎么认识的（如：朋友介绍）", text: $draft.metChannel)
            DatePicker("认识时间", selection: Binding(
                get: { draft.metDate ?? Date() },
                set: { draft.metDate = $0 }
            ), displayedComponents: .date)
        }
    }

    // MARK: 标签

    private var tagsSection: some View {
        Section {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(app.usedTags, id: \.self) { tag in
                    TagChip(
                        title: tag,
                        isOn: draft.tags.contains(tag),
                        tint: Palette.accent
                    ) {
                        toggle(tag: tag)
                    }
                }
                ForEach(TagSuggestions.common.filter { !app.usedTags.contains($0) }, id: \.self) { tag in
                    TagChip(
                        title: tag,
                        isOn: draft.tags.contains(tag),
                        tint: Color.secondary
                    ) {
                        toggle(tag: tag)
                    }
                }
                TagChip(title: "+ 自定义", isOn: false, tint: Color.secondary) {
                    showAddTagDialog = true
                }
            }
        } header: {
            Text("标签")
        } footer: {
            Text("标签用于筛选，不会出现在任何联网功能里。")
        }
    }

    private func toggle(tag: String) {
        if let index = draft.tags.firstIndex(of: tag) {
            draft.tags.remove(at: index)
            Haptics.shared.play(.toggleOff)
        } else {
            draft.tags.append(tag)
            Haptics.shared.play(.toggleOn)
        }
    }

    // MARK: 联系与备注

    private var detailSection: some View {
        Section {
            Picker("联系提醒", selection: $draft.reminderIntervalDays) {
                Text("不提醒").tag(Int?.none)
                Text("7 天").tag(Int?.some(7))
                Text("14 天").tag(Int?.some(14))
                Text("30 天").tag(Int?.some(30))
                Text("60 天").tag(Int?.some(60))
            }

            TextField("联系方式备注", text: $draft.contactNote)

            TextField("备注", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("联系与备注")
        } footer: {
            Text("超过提醒天数没有互动的人，会出现在名单页的「该联系了」提醒里。")
        }
    }

    // MARK: 危险操作

    private var dangerSection: some View {
        Section {
            Button("删除这条档案", role: .destructive) {
                Haptics.shared.play(.warning)
                showDeleteConfirm = true
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 标签 Chip（编辑表单专用）

private struct TagChip: View {
    let title: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                }
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(isOn ? .white : Color.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if isOn {
                    Capsule().fill(tint.gradient)
                }
            }
            .glassCapsule(interactive: true, shadowRadius: 6)
        }
        .buttonStyle(HapticButtonStyle(cue: .selection))
    }
}

// MARK: - 月/日选择

struct MonthDayMenu: View {
    @Binding var month: Int?
    @Binding var day: Int?

    private var monthLabel: String {
        guard let month else { return "未设置" }
        return "\(month) 月 \(day.map { "\($0) 日" } ?? "??")"
    }

    var body: some View {
        Menu {
            Button {
                Haptics.shared.play(.selection)
                month = nil
                day = nil
            } label: {
                if month == nil {
                    Label("清除", systemImage: "checkmark")
                } else {
                    Text("清除")
                }
            }
            Divider()
            ForEach(1...12, id: \.self) { m in
                Button("\(m) 月") {
                    Haptics.shared.play(.selection)
                    month = m
                    if day == nil { day = 1 }
                }
            }
            Divider()
            Menu("具体日期") {
                ForEach(1...31, id: \.self) { d in
                    Button("\(d) 日") {
                        Haptics.shared.play(.selection)
                        day = d
                        if month == nil { month = 1 }
                    }
                }
            }
        } label: {
            Text(monthLabel)
                .foregroundStyle(month == nil ? .secondary : .primary)
        }
    }
}
