import SwiftUI
import UIKit

// MARK: - 对象档案编辑器

struct CompanionEditor: View {

    let initial: Companion
    let recordAfterSaving: Bool

    private enum Page: Int, CaseIterable, Identifiable {
        case basics, preferences, photos
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .basics: "基本资料"
            case .preferences: "偏好与约法"
            case .photos: "照片"
            }
        }
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var movingForward = true
    @State private var page: Page = .basics
    @State private var showBackground = false

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Companion
    @State private var showDeleteConfirm = false
    @State private var isPickingCity = false
    @State private var newTag = ""
    @State private var showAddTagDialog = false
    @State private var showUnsavedAlert = false
    @State private var hasMetDate: Bool
    @State private var pendingAvatarID: String?
    @State private var pendingAvatarPreview: UIImage?
    @State private var removeExistingPhoto = false
    @State private var pendingProfilePhotoIDs: [String] = []
    @State private var pendingAlbumPhotoIDs: [String] = []

    private var isNew: Bool { !app.companions.contains { $0.id == initial.id } }
    private var hasUnsavedChanges: Bool {
        draft != initial
            || pendingAvatarID != nil
            || removeExistingPhoto
            || !pendingProfilePhotoIDs.isEmpty
            || !pendingAlbumPhotoIDs.isEmpty
    }

    init(companion: Companion, recordAfterSaving: Bool = false) {
        self.initial = companion
        self.recordAfterSaving = recordAfterSaving
        _draft = State(initialValue: companion)
        _hasMetDate = State(initialValue: companion.metDate != nil)
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
            .navigationTitle(isNew ? "新增人物" : "编辑人物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { cancel() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("上一步") { changePage(Page(rawValue: page.rawValue - 1) ?? .basics) }
                        .disabled(page == .basics)
                    Spacer()
                    Text("\(page.rawValue + 1) / 3").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if page != .photos {
                        Button("下一步") { changePage(Page(rawValue: page.rawValue + 1) ?? .photos) }
                    } else {
                        Button(recordAfterSaving ? "保存并记这次" : "保存") { save() }
                            .disabled(app.location(id: draft.cityID) == nil)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(recordAfterSaving ? "保存并记这次" : "保存") { save() }
                        .disabled(app.location(id: draft.cityID) == nil)
                        .fontWeight(.semibold)
                        .tint(Palette.accent)
                }
            }
            .navigationDestination(isPresented: $isPickingCity) {
                LocationPickerRoute(cityID: $draft.cityID)
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
                Button("删除她和全部记录", role: .destructive) {
                    discardPendingMedia()
                    app.delete(companionID: initial.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("约过的记录和照片一起删掉，回不来。")
            }
        }
    }

    private var editorForm: some View {
            Form {
                switch page {
                case .basics:
                    basicSection
                    citySection
                    statusSection
                    optionalInfoSection
                case .preferences:
                    playbookSection
                    intimacySection
                    tagsSection
                    scoreSection
                    detailSection
                    if !isNew { dangerSection }
                case .photos:
                    profilePhotosEditorSection
                    privatePhotosEditorSection
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
    }

    private var editorSteps: [NativeEditorStep] {
        [
            NativeEditorStep(title: "基本资料", subtitle: "先记她是谁，再选常驻城市或国家。", symbol: "person.crop.circle"),
            NativeEditorStep(title: "偏好与约法", subtitle: "她喜欢什么、怎么约最顺、说清楚的规矩和你的印象。", symbol: "heart.text.square"),
            NativeEditorStep(title: "照片", subtitle: "人物照和私密照片分开存放。", symbol: "photo.on.rectangle")
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

    private func save() {
        guard app.location(id: draft.cityID) != nil else { changePage(.basics); return }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.contactNote = draft.contactNote.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.rating = draft.scorecard.legacyStarRating
        if let metDate = draft.metDate, metDate > Date() {
            draft.metDate = Date()
        }
        if let pendingAvatarID {
            draft.photoID = pendingAvatarID
        } else if removeExistingPhoto {
            draft.photoID = nil
        }
        commitPendingPhotos()
        app.upsert(draft)
        releasePendingReferences()
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
        discardPendingMedia()
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
                hasPhoto: (draft.photoID != nil && !removeExistingPhoto) || pendingAvatarID != nil
            ) { importedID in
                if let oldID = pendingAvatarID, oldID != importedID {
                    MediaStore.delete(id: oldID)
                }
                pendingAvatarID = importedID
                pendingAvatarPreview = MediaStore.image(id: importedID)
                removeExistingPhoto = false
            } onRemove: {
                discardPendingAvatar()
                removeExistingPhoto = draft.photoID != nil
            }

            HStack {
                Text("没照片就用")
                Spacer()
                TextField("emoji 或首字", text: $draft.emoji)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 160)
                    .textInputAutocapitalization(.never)
            }

            TextField("微信号 / 手机号 / 其他联系方式", text: $draft.contactNote)
        }
    }

    private var profilePhotosEditorSection: some View {
        Section {
            if !draft.profilePhotoIDs.isEmpty {
                PhotoStrip(ids: Array(draft.profilePhotoIDs.prefix(12)))
            }

            if !pendingProfilePhotoIDs.isEmpty {
                PhotoStrip(
                    ids: pendingProfilePhotoIDs,
                    editable: true,
                    onDelete: { id in
                        MediaStore.delete(id: id)
                        pendingProfilePhotoIDs.removeAll { $0 == id }
                    }
                )
            }

            PhotoAddBar { importedIDs in
                pendingProfilePhotoIDs.append(contentsOf: importedIDs)
                Haptics.shared.play(.toggleOn)
            }

            if !pendingProfilePhotoIDs.isEmpty {
                Button("清除本次人物照", role: .destructive) {
                    MediaStore.delete(ids: pendingProfilePhotoIDs)
                    pendingProfilePhotoIDs = []
                }
            }
        } header: {
            HStack {
                Text("人物照")
                Spacer()
                Text(photoCountText(saved: draft.profilePhotoIDs.count, pending: pendingProfilePhotoIDs.count))
            }
        } footer: {
            Text("普通照片放这里，和艳照分开；不限数量，原图保存。已保存的照片在档案页里删。")
        }
    }

    private var privatePhotosEditorSection: some View {
        Section {
            if !draft.albumPhotoIDs.isEmpty {
                PhotoStrip(ids: Array(draft.albumPhotoIDs.prefix(12)))
            }

            if !pendingAlbumPhotoIDs.isEmpty {
                PhotoStrip(
                    ids: pendingAlbumPhotoIDs,
                    editable: true,
                    onDelete: { id in
                        MediaStore.delete(id: id)
                        pendingAlbumPhotoIDs.removeAll { $0 == id }
                    }
                )
            }

            PhotoAddBar { importedIDs in
                pendingAlbumPhotoIDs.append(contentsOf: importedIDs)
                Haptics.shared.play(.toggleOn)
            }

            if !pendingAlbumPhotoIDs.isEmpty {
                Button("清除本次艳照", role: .destructive) {
                    MediaStore.delete(ids: pendingAlbumPhotoIDs)
                    pendingAlbumPhotoIDs = []
                }
            }
        } header: {
            HStack {
                Text("艳照私藏")
                Spacer()
                Text(photoCountText(saved: draft.albumPhotoIDs.count, pending: pendingAlbumPhotoIDs.count))
            }
        } footer: {
            Text("只放私密照片；不限数量，原图保存，代号打码时会一起糊掉。")
        }
    }

    private func photoCountText(saved: Int, pending: Int) -> String {
        pending > 0 ? "已存 \(saved) · 待保存 \(pending)" : "已存 \(saved)"
    }

    private func commitPendingPhotos() {
        var profileIDs = Set(draft.profilePhotoIDs)
        draft.profilePhotoIDs.append(contentsOf: pendingProfilePhotoIDs.filter {
            profileIDs.insert($0).inserted
        })

        var albumIDs = Set(draft.albumPhotoIDs)
        draft.albumPhotoIDs.append(contentsOf: pendingAlbumPhotoIDs.filter {
            albumIDs.insert($0).inserted
        })
    }

    private func discardPendingAvatar() {
        if let pendingAvatarID { MediaStore.delete(id: pendingAvatarID) }
        pendingAvatarID = nil
        pendingAvatarPreview = nil
    }

    private func discardPendingMedia() {
        discardPendingAvatar()
        MediaStore.delete(ids: pendingProfilePhotoIDs + pendingAlbumPhotoIDs)
        pendingProfilePhotoIDs = []
        pendingAlbumPhotoIDs = []
    }

    /// 清空“待提交”标记，但保留刚刚已经写入并被档案引用的源文件。
    private func releasePendingReferences() {
        pendingAvatarID = nil
        pendingAvatarPreview = nil
        pendingProfilePhotoIDs = []
        pendingAlbumPhotoIDs = []
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let pendingAvatarPreview {
            Image(uiImage: pendingAvatarPreview)
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
        Section("现在是什么关系 · 单选") {
            FlowLayout(spacing: 7, lineSpacing: 8) {
                ForEach(RelationStage.allCases) { stage in
                    RecordChoice(title: stage.label, isOn: draft.stage == stage, tint: stage.tint, compact: true) {
                        draft.stage = stage
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var scoreSection: some View {
        Section {
            NavigationLink {
                CompanionScoreEditor(scorecard: $draft.scorecard)
            } label: {
                ScorecardEditorLink(scorecard: draft.scorecard)
            }
        } header: {
            Text("我对她的评分")
        } footer: {
            Text("颜值、身材、床上默契、主动感、欲望值和回味欲；不了解的项可以不打分。")
        }
    }

    // MARK: 见她之前看一眼

    private var playbookSection: some View {
        Section {
            SuggestedNotesField(
                title: "她在床上喜欢什么",
                placeholder: "敏感点、喜欢的节奏和姿势，可自己写",
                text: $draft.turnOns,
                suggestions: ProfileSuggestions.turnOns
            )
            SuggestedNotesField(
                title: "怎么约她最顺",
                placeholder: "开口方式、她方便的时间、要避开的雷",
                text: $draft.approachNotes,
                suggestions: ProfileSuggestions.approach
            )
        } header: {
            Text("见她之前看一眼")
        } footer: {
            Text("这两条会显示在她的档案最上面，也会在记上床时提示。只写你真的观察到的。")
        }
    }

    // MARK: 期待、边界与安全

    private var intimacySection: some View {
        Section {
            SuggestedNotesField(title: "想怎么约", placeholder: "关系期待，可自己写", text: $draft.expectations, suggestions: ProfileSuggestions.expectations)
            SuggestedNotesField(title: "已经说清楚的规矩", placeholder: "不接受什么、哪些事要先问", text: $draft.boundaries, suggestions: ProfileSuggestions.boundaries)
            TextField("安全备忘（检测、套、别的）", text: $draft.safetyNotes, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("怎么约、什么不能碰")
        } footer: {
            Text("只记双方已经说清楚的。她随时可以改主意。")
        }
    }

    // MARK: 地点与认识渠道

    private var citySection: some View {
        Section("常驻地点与认识方式") {
            Button {
                Haptics.shared.play(.lightTap)
                isPickingCity = true
            } label: {
                HStack {
                    Label(app.location(id: draft.cityID)?.name ?? "选择常驻城市 / 国家", systemImage: "mappin.circle.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    ChevronHint()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("怎么认识的，也可自己写", text: $draft.metChannel)
            DisclosureGroup("选择认识渠道 · 单选") {
                ForEach(ProfileSuggestions.channels) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title).font(.caption).foregroundStyle(.secondary)
                        FlowLayout(spacing: 7, lineSpacing: 8) {
                            ForEach(group.options, id: \.self) { option in
                                RecordChoice(title: option, isOn: draft.metChannel == option, tint: Palette.accent, compact: true) {
                                    draft.metChannel = draft.metChannel == option ? "" : option
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
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
            if !draft.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已选 \(draft.tags.count) 项 · 点标签取消").font(.caption).foregroundStyle(.secondary)
                    tagChoices(draft.tags)
                }
            }
            ForEach(TagSuggestions.groups) { group in
                DisclosureGroup {
                    tagChoices(group.options)
                } label: {
                    HStack {
                        Text(group.title)
                        Spacer()
                        Text("\(group.options.filter { draft.tags.contains($0) }.count) / \(group.options.count)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            let custom = app.usedTags.filter { !TagSuggestions.common.contains($0) && !draft.tags.contains($0) }
            if !custom.isEmpty {
                DisclosureGroup("用过的自定义标签") { tagChoices(custom) }
            }
            Button("添加自定义标签") { showAddTagDialog = true }
        } header: {
            Text("人物标签 · 可多选")
        } footer: {
            Text("标签方便搜索和筛选。偏好只记已经沟通过的，每次仍需确认。")
        }
    }

    private func tagChoices(_ options: [String]) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(options, id: \.self) { tag in
                RecordChoice(title: tag, isOn: draft.tags.contains(tag), tint: Palette.accent, compact: true) {
                    toggle(tag: tag)
                }
            }
        }
        .padding(.vertical, 4)
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
        Section {
            DisclosureGroup("年龄、身材、生日与职业（可选）", isExpanded: $showBackground) {
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

                Picker("下胸围", selection: $draft.bustBandCM) {
                    Text("未设置").tag(Int?.none)
                    ForEach(Array(stride(from: 60, through: 110, by: 5)), id: \.self) { cm in
                        Text("\(cm) cm").tag(Int?.some(cm))
                    }
                }

                Picker("罩杯", selection: $draft.bustSize) {
                    ForEach(BustSize.allCases) { size in
                        Text(size.label).tag(size)
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
            Text("联系提醒与备注")
        } footer: {
            Text("只在 App 内提示联系周期，不会自动发消息。")
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
