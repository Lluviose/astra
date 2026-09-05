import SwiftUI
import UIKit

// MARK: - 对象档案编辑器

struct CompanionEditor: View {

    let initial: Companion
    var continuesToRecord = false

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showProfileDetails = false
    @State private var draft: Companion
    @State private var ageText: String
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
    @State private var pendingDossierPhotoIDs: [String] = []
    @State private var pendingAlbumPhotoIDs: [String] = []

    private var isNew: Bool { !app.companions.contains { $0.id == initial.id } }
    private var hasUnsavedChanges: Bool {
        draft != initial
            || pendingAvatarID != nil
            || removeExistingPhoto
            || !pendingProfilePhotoIDs.isEmpty
            || !pendingDossierPhotoIDs.isEmpty
            || !pendingAlbumPhotoIDs.isEmpty
    }

    init(companion: Companion, continuesToRecord: Bool = false) {
        self.continuesToRecord = continuesToRecord
        self.initial = companion
        _draft = State(initialValue: companion)
        _ageText = State(initialValue: companion.age.map(String.init) ?? "")
        _hasMetDate = State(initialValue: companion.metDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                Section {
                    Toggle("完善档案", isOn: $showProfileDetails)
                } footer: {
                    Text("只需一个代号就能开始。关系、地点、照片和其他资料可以稍后补充。")
                }
                if showProfileDetails {
                    statusSection
                    citySection
                    tagsSection
                    profilePhotosEditorSection
                    dossierPhotosEditorSection
                    privatePhotosEditorSection
                    scoreSection
                    intimacySection
                    optionalInfoSection
                    detailSection
                }
                if !isNew {
                    dangerSection
                }
            }
            .astraListStyle()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "新建档案" : "编辑档案")
            .onAppear { showProfileDetails = !isNew }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { cancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(continuesToRecord ? "保存并记录" : "保存") { save() }
                        .accessibilityIdentifier("companion-save")
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

    private func save() {
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
        Section(continuesToRecord ? "这次和谁" : "人物代号") {
            HStack(spacing: 12) {
                avatarPreview
                TextField("代号（可留空）", text: $draft.name)
                    .accessibilityIdentifier("companion-name")
                    .textInputAutocapitalization(.never)
            }

            if showProfileDetails {
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

            TextField("联系方式备注", text: $draft.contactNote)
            }
        }
    }

    private var profilePhotosEditorSection: some View {
        Section {
            Label(
                "已存 \(draft.profilePhotoIDs.count) · 待保存 \(pendingProfilePhotoIDs.count)",
                systemImage: "person.crop.rectangle.stack.fill"
            )
            .font(.subheadline)

            PhotoAddBar { importedIDs in
                pendingProfilePhotoIDs.append(contentsOf: importedIDs)
            }

            if !pendingProfilePhotoIDs.isEmpty {
                Button("清除本次人物照", role: .destructive) {
                    MediaStore.delete(ids: pendingProfilePhotoIDs)
                    pendingProfilePhotoIDs = []
                }
            }
        } header: {
            Text("人物照")
        } footer: {
            Text("普通人物照片放这里，与私密相册分开；不限数量，原图保存。")
        }
    }

    private var privatePhotosEditorSection: some View {
        Section {
            Label(
                "已存 \(draft.albumPhotoIDs.count) · 待保存 \(pendingAlbumPhotoIDs.count)",
                systemImage: "photo.on.rectangle.angled"
            )
            .font(.subheadline)

            PhotoAddBar { importedIDs in
                pendingAlbumPhotoIDs.append(contentsOf: importedIDs)
            }

            if !pendingAlbumPhotoIDs.isEmpty {
                Button("清除本次艳照", role: .destructive) {
                    MediaStore.delete(ids: pendingAlbumPhotoIDs)
                    pendingAlbumPhotoIDs = []
                }
            }
        } header: {
            Text("私密相册")
        } footer: {
            Text("只放私密照片；不限数量，原图保存，代号打码时会一起糊掉。")
        }
    }

    private var dossierPhotosEditorSection: some View {
        Section {
            Label(
                "已存 \(draft.dossierPhotoIDs.count) · 待保存 \(pendingDossierPhotoIDs.count)",
                systemImage: "person.text.rectangle.fill"
            )
            .font(.subheadline)

            PhotoAddBar { importedIDs in
                pendingDossierPhotoIDs.append(contentsOf: importedIDs)
            }

            if !pendingDossierPhotoIDs.isEmpty {
                Button("清除本次档案照片", role: .destructive) {
                    MediaStore.delete(ids: pendingDossierPhotoIDs)
                    pendingDossierPhotoIDs = []
                }
            }
        } header: {
            Text("档案照片")
        } footer: {
            Text("个人资料页、人物信息截图等放这里；不限数量，原图保存。")
        }
    }

    private func commitPendingPhotos() {
        var profileIDs = Set(draft.profilePhotoIDs)
        draft.profilePhotoIDs.append(contentsOf: pendingProfilePhotoIDs.filter {
            profileIDs.insert($0).inserted
        })

        var dossierIDs = Set(draft.dossierPhotoIDs)
        draft.dossierPhotoIDs.append(contentsOf: pendingDossierPhotoIDs.filter {
            dossierIDs.insert($0).inserted
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
        MediaStore.delete(ids: pendingProfilePhotoIDs + pendingDossierPhotoIDs + pendingAlbumPhotoIDs)
        pendingProfilePhotoIDs = []
        pendingDossierPhotoIDs = []
        pendingAlbumPhotoIDs = []
    }

    /// 清空“待提交”标记，但保留刚刚已经写入并被档案引用的源文件。
    private func releasePendingReferences() {
        pendingAvatarID = nil
        pendingAvatarPreview = nil
        pendingProfilePhotoIDs = []
        pendingDossierPhotoIDs = []
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
        Section("相处状态") {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(RelationStage.allCases) { stage in
                    GlassChip(title: stage.label, systemImage: stage.symbolName, isOn: draft.stage == stage) {
                        draft.stage = stage
                    }
                }
            }.padding(.vertical, 4)
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
            Text("这一眼的感觉")
        } footer: {
            Text("六维评分只给你自己看，会同步成旧版五星，方便筛选和备份。")
        }
    }

    // MARK: 期待、边界与安全

    private var intimacySection: some View {
        Section {
            TextField("想怎么约（只约、当炮友、固定、先看看）", text: $draft.expectations, axis: .vertical)
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

    // MARK: 地点与认识渠道

    private var citySection: some View {
        Section("哪儿认识的") {
            Button {
                Haptics.shared.play(.lightTap)
                isPickingCity = true
            } label: {
                HStack {
                    Label(app.locationName(for: draft), systemImage: "mappin.circle.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    ChevronHint()
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
            Text("方便以后翻出来，也能在名册里按标签筛。")
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
            HStack {
                Text("年龄")
                Spacer()
                TextField("未设置", text: $ageText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .onChange(of: ageText) { _, newValue in
                        let digits = String(newValue.filter { $0.isNumber }.prefix(3))
                        if ageText != digits {
                            ageText = digits
                        }
                        draft.age = Int(digits)
                    }
                Text("岁")
                    .foregroundStyle(.secondary)
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
