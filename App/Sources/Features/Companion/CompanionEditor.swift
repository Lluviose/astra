import SwiftUI
import UIKit

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

// MARK: - 对象档案编辑器

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
    @State private var hasMetDate: Bool
    @State private var pendingAvatar: UIImage?
    @State private var removeExistingPhoto = false

    private var isNew: Bool { !app.companions.contains { $0.id == initial.id } }
    private var hasUnsavedChanges: Bool {
        draft != initial || pendingAvatar != nil || removeExistingPhoto
    }

    init(companion: Companion) {
        self.initial = companion
        _draft = State(initialValue: companion)
        _hasMetDate = State(initialValue: companion.metDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                statusSection
                intimacySection
                citySection
                tagsSection
                optionalInfoSection
                detailSection
                if !isNew {
                    dangerSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "记下她" : "改档案")
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
            }
            .navigationDestination(isPresented: $isPickingCity) {
                EditorCityPickerRoute(cityID: $draft.cityID)
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .onChange(of: hasMetDate) { _, enabled in
                if enabled, draft.metDate == nil {
                    draft.metDate = Date()
                } else if !enabled {
                    draft.metDate = nil
                }
            }
            .alert("放弃未保存的修改？", isPresented: $showUnsavedAlert) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { abandon() }
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
                Button("删除对象及全部记录", role: .destructive) {
                    app.delete(companionID: initial.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("连同约过的记录和照片一起删掉，回不来。")
            }
        }
    }

    private func save() {
        draft.rating = min(max(draft.rating, 0), 5)
        if let metDate = draft.metDate, metDate > Date() {
            draft.metDate = Date()
        }
        if let pendingAvatar {
            draft.photoID = MediaStore.save(image: pendingAvatar, kind: .avatar)
        } else if removeExistingPhoto {
            draft.photoID = nil
        }
        app.upsert(draft)
        dismiss()
    }

    private func cancel() {
        if hasUnsavedChanges {
            showUnsavedAlert = true
        } else {
            dismiss()
        }
    }

    private func abandon() {
        dismiss()
    }

    // MARK: 基本信息

    private var basicSection: some View {
        Section("她是谁") {
            HStack(spacing: 12) {
                avatarPreview
                TextField("怎么叫她（可留空）", text: $draft.name)
                    .textInputAutocapitalization(.never)
            }

            AvatarPickerRow(
                hasPhoto: (draft.photoID != nil && !removeExistingPhoto) || pendingAvatar != nil
            ) { image in
                pendingAvatar = image
                removeExistingPhoto = false
            } onRemove: {
                pendingAvatar = nil
                removeExistingPhoto = true
            }

            HStack {
                Text("没照片就用")
                Spacer()
                TextField("emoji 或首字", text: $draft.emoji)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 160)
                    .textInputAutocapitalization(.never)
            }

            TextField("微信 / 备注名", text: $draft.contactNote)
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let pendingAvatar {
            Image(uiImage: pendingAvatar)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else if removeExistingPhoto {
            AvatarView(
                text: draft.initial,
                paletteIndex: draft.paletteIndex,
                size: 56,
                ringColor: nil,
                photoID: nil,
                ignorePrivacyMask: true
            )
        } else {
            AvatarView(companion: draft, size: 56, showRing: false, ignorePrivacyMask: true)
        }
    }

    // MARK: 相处状态

    private var statusSection: some View {
        Section("相处状态") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RelationStage.allCases, id: \.self) { stage in
                        Button {
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
                Text("默契度")
                Spacer()
                RatingPicker(rating: $draft.rating, size: 24)
            }
        }
    }

    // MARK: 期待、边界与安全

    private var intimacySection: some View {
        Section {
            TextField("想怎么约（只约、固定约、先看看）", text: $draft.expectations, axis: .vertical)
                .lineLimit(2...4)
            TextField("她说过不行的事", text: $draft.boundaries, axis: .vertical)
                .lineLimit(2...5)
            TextField("安全备忘（检测、套、别的）", text: $draft.safetyNotes, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("怎么约、什么不能碰")
        } footer: {
            Text("只记双方已经说清楚的。她随时可以改主意。")
        }
    }

    // MARK: 城市与认识渠道

    private var citySection: some View {
        Section("哪儿认识的") {
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

            TextField("怎么认识的（App、朋友、酒局…）", text: $draft.metChannel)
            Toggle("记下认识那天", isOn: $hasMetDate)
            if hasMetDate {
                DatePicker(
                    "第一次碰上",
                    selection: Binding(
                        get: { draft.metDate ?? Date() },
                        set: { draft.metDate = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
            }
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
                        tint: Palette.accent,
                        cue: draft.tags.contains(tag) ? .toggleOff : .toggleOn
                    ) {
                        toggle(tag: tag)
                    }
                }
                ForEach(TagSuggestions.common.filter { !app.usedTags.contains($0) }, id: \.self) { tag in
                    TagChip(
                        title: tag,
                        isOn: draft.tags.contains(tag),
                        tint: Color.secondary,
                        cue: draft.tags.contains(tag) ? .toggleOff : .toggleOn
                    ) {
                        toggle(tag: tag)
                    }
                }
                TagChip(title: "+ 自定义", isOn: false, tint: Color.secondary, cue: .lightTap) {
                    showAddTagDialog = true
                }
            }
        } header: {
            Text("标签")
        } footer: {
            Text("方便以后翻出来，只存在这台手机。")
        }
    }

    private func toggle(tag: String) {
        if let index = draft.tags.firstIndex(of: tag) {
            draft.tags.remove(at: index)
        } else {
            draft.tags.append(tag)
        }
    }

    // MARK: 可选背景

    private var optionalInfoSection: some View {
        Section("可选背景") {
            Picker("年龄", selection: $draft.age) {
                Text("未设置").tag(Int?.none)
                ForEach(18...80, id: \.self) { age in
                    Text("\(age)").tag(Int?.some(age))
                }
            }

            Picker("身高", selection: $draft.heightCM) {
                Text("未设置").tag(Int?.none)
                ForEach(140...210, id: \.self) { cm in
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

    // MARK: 联系节奏与备注

    private var detailSection: some View {
        Section {
            Picker("联系周期", selection: $draft.reminderIntervalDays) {
                Text("不设置").tag(Int?.none)
                Text("7 天").tag(Int?.some(7))
                Text("14 天").tag(Int?.some(14))
                Text("30 天").tag(Int?.some(30))
                Text("60 天").tag(Int?.some(60))
            }

            TextField("其他私密备注", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("多久约一次")
        } footer: {
            Text("到点只轻轻提醒一下，不想约就别理。")
        }
    }

    // MARK: 危险操作

    private var dangerSection: some View {
        Section {
            Button("删掉这个人", role: .destructive) {
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
    let cue: HapticCue
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
        .buttonStyle(HapticButtonStyle(cue: cue))
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
                    day = min(day ?? 1, daysInMonth(m))
                }
            }
            if let month {
                Divider()
                Menu("具体日期") {
                    ForEach(1...daysInMonth(month), id: \.self) { d in
                        Button("\(d) 日") {
                            Haptics.shared.play(.selection)
                            day = d
                        }
                    }
                }
            }
        } label: {
            Text(monthLabel)
                .foregroundStyle(month == nil ? .secondary : .primary)
        }
    }

    private func daysInMonth(_ month: Int) -> Int {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2024 // 闰年，允许记录 2 月 29 日生日。
        components.month = month
        components.day = 1
        guard let date = components.date,
              let range = components.calendar?.range(of: .day, in: .month, for: date)
        else { return 31 }
        return range.count
    }
}
