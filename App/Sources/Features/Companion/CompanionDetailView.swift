import SwiftUI

/// 猎获档案：封面、战绩小结、照片、评分、规矩、线索和她的时间线。
struct CompanionDetailView: View {

    let companionID: UUID

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var showEditor = false
    @State private var scoreDraft: CompanionScorecard?
    @State private var detailSection: DetailSection = .records
    @State private var pendingRecordDeletion: Encounter?

    private enum DetailSection: String, CaseIterable, Identifiable {
        case records = "战绩", profile = "画像", photos = "私藏"
        var id: String { rawValue }
    }
    @State private var editingEncounter: Encounter?
    @State private var showDeleteConfirm = false
    @State private var viewingPhotoIndex: Int?
    @State private var viewingPhotoIDs: [String] = []
    @State private var photoShelf: PhotoShelf = .album

    private enum PhotoShelf: String, CaseIterable, Identifiable {
        case album
        case profile
        case dossier

        var id: String { rawValue }
    }

    private var companion: Companion? { app.companion(id: companionID) }

    var body: some View {
        Group {
            if let companion {
                content(companion)
            } else {
                EmptyStateView(symbol: "person.crop.circle.badge.questionmark", title: "档案不存在", message: "这页可能已经从名册里撕掉了。")
            }
        }
        .toolbar {
            if let companion {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.shared.play(.lightTap)
                        showEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("编辑")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            app.togglePin(companion)
                        } label: {
                            Label(
                                companion.isPinned ? "取消置顶" : "置顶",
                                systemImage: companion.isPinned ? "pin.slash" : "pin.fill"
                            )
                        }
                        Button {
                            app.toggleArchive(companion)
                        } label: {
                            Label(
                                companion.isArchived ? "恢复到名册" : "归档",
                                systemImage: companion.isArchived ? "tray.and.arrow.up" : "archivebox"
                            )
                        }
                        Button {
                            app.toggleNamesRevealed()
                        } label: {
                            Label(app.namesRevealed ? "隐藏代号和照片" : "显示代号和照片", systemImage: app.namesRevealed ? "eye.slash" : "eye")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Haptics.shared.play(.warning)
                            showDeleteConfirm = true
                        } label: {
                            Label("删除档案", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let companion { CompanionEditor(companion: companion) }
        }
        .sheet(isPresented: Binding(
            get: { scoreDraft != nil }, set: { if !$0 { scoreDraft = nil } }
        )) {
            NavigationStack {
                CompanionScoreEditor(scorecard: Binding(
                    get: { scoreDraft ?? .empty }, set: { scoreDraft = $0 }
                ))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { scoreDraft = nil }
                            .accessibilityIdentifier("cancel-person-score")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if var person = companion, let score = scoreDraft {
                                person.scorecard = score
                                app.upsert(person)
                            }
                            scoreDraft = nil
                        }.accessibilityIdentifier("save-person-score")
                    }
                }
            }
        }
        .sheet(item: $editingEncounter) { encounter in
            EncounterEditor(encounter: encounter)
        }
        .confirmationDialog(
            "删除这条档案？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除她和全部记录", role: .destructive) {
                app.delete(companionID: companionID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("约过的记录和照片一起删掉，回不来。")
        }
        .confirmationDialog("删除这篇记录？", isPresented: Binding(
            get: { pendingRecordDeletion != nil },
            set: { if !$0 { pendingRecordDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                if let record = pendingRecordDeletion { app.delete(encounterID: record.id) }
                pendingRecordDeletion = nil
            }
            Button("取消", role: .cancel) { pendingRecordDeletion = nil }
        }
        .sheet(isPresented: Binding(
            get: { viewingPhotoIndex != nil },
            set: { if !$0 { viewingPhotoIndex = nil } }
        )) {
            PhotoViewer(ids: viewingPhotoIDs, index: viewingPhotoIndex ?? 0)
        }
    }

    // MARK: 内容

    private func content(_ companion: Companion) -> some View {
        List {
            heroSection(companion)
            if companion.isArchived {
                Section {
                    Label("已归档，记录与照片仍然保留", systemImage: "archivebox.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let overdueNote = overdueNote(companion) {
                Section {
                    Label(overdueNote, systemImage: "bell.badge.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
            }
            Section {
                Picker("档案内容", selection: $detailSection) {
                    ForEach(DetailSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("dossier-section")
            }
            switch detailSection {
            case .records: timelineSection(companion)
            case .photos: photosSection(companion)
            case .profile:
                scoreSection(companion)
                relationshipSection(companion)
                if hasIntimacyNotes(companion) { intimacyInfoSection(companion) }
                infoSection(companion)
            }
        }
        .listStyle(.insetGrouped)
        .astraListStyle()
        .navigationTitle(app.namesRevealed ? companion.displayName : "档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 封面

    private func heroSection(_ companion: Companion) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    AvatarView(companion: companion, size: 64, showRing: false)
                    VStack(alignment: .leading, spacing: 8) {
                        MaskedName(name: companion.displayName, revealed: app.namesRevealed,
                                   font: .system(.title, design: .serif))
                        FlowLayout(spacing: 8, lineSpacing: 6) {
                            Text(companion.stage.label).foregroundStyle(companion.stage.tint)
                            if !companion.cityID.isEmpty {
                                Text(app.locationName(for: companion)).foregroundStyle(Palette.secondaryInk)
                            }
                        }.font(.caption)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    let tier = CompanionLegendTier.resolve(hookupCount: app.hookupCount(for: companion.id))
                    TagLabel(title: tier.label, systemImage: tier.symbolName, tint: Palette.accent)
                    Spacer()
                    Button {
                        app.togglePin(companion)
                    } label: {
                        Label(companion.isPinned ? "已偏爱" : "设为偏爱", systemImage: companion.isPinned ? "heart.fill" : "heart")
                            .font(.caption).frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                }
                Text("\(app.encounters(for: companion.id).count) 篇相处记录 · \(app.albumIDs(for: companion.id).count) 张照片")
                    .font(.subheadline).foregroundStyle(Palette.secondaryInk)
                Button {
                    editingEncounter = Encounter(companionID: companion.id, kind: .intimacy,
                                                 cityID: companion.cityID.isEmpty ? nil : companion.cityID)
                } label: {
                    PrimaryActionLabel(title: "记录一次相处", systemImage: "square.and.pencil")
                }
                .buttonStyle(HapticButtonStyle())
                .accessibilityIdentifier("dossier-record")
            }
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: 照片

    private func photosSection(_ companion: Companion) -> some View {
        let albumIDs = app.albumIDs(for: companion.id)
        let profileIDs = app.profilePhotoIDs(for: companion.id)
        let dossierIDs = app.dossierPhotoIDs(for: companion.id)
        let ids: [String]
        let footer: String
        switch photoShelf {
        case .album:
            ids = albumIDs
            footer = "私密照片和每次留下的照片放这里，不限数量，原图保存。"
        case .profile:
            ids = profileIDs
            footer = "头像和普通人物照放这里，不会混进私密照片。"
        case .dossier:
            ids = dossierIDs
            footer = "个人资料页、人物信息截图等档案照片放这里。"
        }
        return Section {
            Picker("照片", selection: $photoShelf) {
                Text("私密照片 \(albumIDs.count)").tag(PhotoShelf.album)
                Text("人物照 \(profileIDs.count)").tag(PhotoShelf.profile)
                Text("档案照 \(dossierIDs.count)").tag(PhotoShelf.dossier)
            }
            .pickerStyle(.segmented)

            if !ids.isEmpty {
                if app.namesRevealed {
                    PhotoStrip(
                        ids: ids,
                        editable: true,
                        onDelete: { id in
                            switch photoShelf {
                            case .album:
                                app.removeAlbumPhoto(id, from: companion.id)
                            case .profile:
                                app.removeProfilePhoto(id, from: companion.id)
                            case .dossier:
                                app.removeDossierPhoto(id, from: companion.id)
                            }
                        },
                        onOpen: {
                            viewingPhotoIDs = ids
                            viewingPhotoIndex = $0
                        }
                    )
                } else {
                    Label("点右上角菜单里的眼睛再看照片", systemImage: "eye.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            PhotoAddBar { importedIDs in
                switch photoShelf {
                case .album:
                    app.addAlbumPhotoIDs(importedIDs, to: companion.id)
                case .profile:
                    app.addProfilePhotoIDs(importedIDs, to: companion.id)
                case .dossier:
                    app.addDossierPhotoIDs(importedIDs, to: companion.id)
                }
            }
        } header: {
            Text("照片")
        } footer: {
            Text(footer)
        }
    }

    // MARK: 相处

    private func relationshipSection(_ companion: Companion) -> some View {
        Section("关系状态") {
            Menu {
                ForEach(RelationStage.allCases) { stage in
                    Button {
                        app.setStage(stage, for: companion)
                    } label: {
                        if companion.stage == stage {
                            Label(stage.label, systemImage: "checkmark")
                        } else {
                            Text(stage.label)
                        }
                    }
                }
            } label: {
                HStack {
                    StageBadge(stage: companion.stage)
                    Spacer()
                    Text("更改")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func scoreSection(_ companion: Companion) -> some View {
        Section {
            CompanionScoreSummaryView(scorecard: companion.scorecard)
                .padding(.vertical, 6)

            Button {
                Haptics.shared.play(.lightTap)
                scoreDraft = companion.scorecard
            } label: {
                Label("调整六维评分", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("edit-person-score")
            .font(.subheadline.weight(.semibold))
            .tint(Palette.coral)
        } header: {
            HStack {
                Text("私密评分")
                Spacer()
                CompanionScoreBadge(score: companion.overallScore, compact: true)
            }
        }
    }

    // MARK: 边界与安全

    private func intimacyInfoSection(_ companion: Companion) -> some View {
        Section("沟通与边界") {
            if !companion.expectations.isEmpty {
                privateNoteRow("相处期待", symbol: "text.bubble.fill", text: companion.expectations, tint: Palette.accent)
            }
            if !companion.boundaries.isEmpty {
                privateNoteRow("已沟通的边界", symbol: "hand.raised.fill", text: companion.boundaries, tint: Palette.warning)
            }
            if !companion.safetyNotes.isEmpty {
                privateNoteRow("安全备忘", symbol: "checkmark.shield.fill", text: companion.safetyNotes, tint: Palette.safe)
            }
        }
    }

    private func privateNoteRow(_ title: String, symbol: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func hasIntimacyNotes(_ companion: Companion) -> Bool {
        !companion.expectations.isEmpty || !companion.boundaries.isEmpty || !companion.safetyNotes.isEmpty
    }

    // MARK: 信息

    private func infoSection(_ companion: Companion) -> some View {
        Section("基本线索") {
            if let days = companion.daysUntilBirthday {
                LabeledContent("生日") {
                    HStack(spacing: 5) {
                        Text(companion.birthdayText ?? "—")
                        Text(Format.birthdayCountdown(days: days))
                            .font(.caption)
                            .foregroundStyle(days <= 14 ? Palette.accent : .secondary)
                    }
                }
            }
            if let age = companion.age {
                LabeledContent("年龄", value: "\(age) 岁")
            }
            if let height = companion.heightCM {
                LabeledContent("身高", value: "\(height) cm")
            }
            if let bustSize = companion.bustSizeText {
                LabeledContent("胸部尺码", value: bustSize)
            }
            if !companion.occupation.isEmpty {
                LabeledContent("职业", value: companion.occupation)
            }
            if !companion.metChannel.isEmpty {
                LabeledContent("认识渠道", value: companion.metChannel)
            }
            if let metDate = companion.metDate {
                LabeledContent("认识时间", value: DateFormatter.dayFull.string(from: metDate))
            }
            if !companion.contactNote.isEmpty {
                LabeledContent("联系方式", value: companion.contactNote)
            }
            if !companion.tags.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(companion.tags, id: \.self) { tag in
                        TagLabel(title: tag)
                    }
                }
                .padding(.vertical, 2)
            }
            if !companion.notes.isEmpty {
                Text(companion.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if companion.age == nil, companion.heightCM == nil, companion.bustSizeText == nil,
               companion.occupation.isEmpty, companion.metChannel.isEmpty, companion.metDate == nil,
               companion.contactNote.isEmpty, companion.tags.isEmpty, companion.notes.isEmpty,
               companion.daysUntilBirthday == nil {
                Button {
                    Haptics.shared.play(.lightTap)
                    showEditor = true
                } label: {
                    Label("补充人物资料", systemImage: "square.and.pencil")
                        .font(.footnote)
                }
            }
        }
    }

    // MARK: 时间线

    private func timelineSection(_ companion: Companion) -> some View {
        Section {
            let encounters = app.encounters(for: companion.id)
            if encounters.isEmpty {
                Text("还没有记录。点「记录一次相处」，留下第一个片刻。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(encounters) { encounter in
                    Button {
                        Haptics.shared.play(.selection)
                        editingEncounter = encounter
                    } label: {
                        EncounterRow(encounter: encounter, showName: false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingRecordDeletion = encounter
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("相处记录")
                Spacer()
                Text("\(app.encounters(for: companion.id).count) 条")
            }
        }
    }

    private func overdueNote(_ companion: Companion) -> String? {
        guard app.isOverdue(companion), let interval = companion.reminderIntervalDays else { return nil }
        return "已经 \(interval) 天没约了。想见再开口，不必硬聊。"
    }
}

// MARK: - 记录行（详情页 & 时间线共用）

struct EncounterRow: View {
    let encounter: Encounter
    var showName: Bool = true
    var showTime: Bool = false

    @Environment(AppState.self) private var app

    private var companion: Companion? { app.companion(id: encounter.companionID) }
    private var locationName: String? {
        encounter.cityID.flatMap { app.location(id: $0)?.name }
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: encounter.kind.symbolName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(encounter.kind.tint)
                .frame(width: 34, height: 38)
                .background(encounter.kind.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 9) {
                FlowLayout(spacing: 10, lineSpacing: 6) {
                    if showName, let companion {
                        MaskedName(name: companion.displayName, revealed: app.namesRevealed,
                                   font: .subheadline.weight(.semibold))
                    }
                    Text(encounter.kind.label)
                        .font(.caption)
                        .foregroundStyle(encounter.kind.tint)
                }
                FlowLayout(spacing: 10, lineSpacing: 6) {
                    Text(showTime ? Format.clockTime(encounter.date) : Format.relativeDay(encounter.date))
                        .monospacedDigit()
                    if let locationName { Label(locationName, systemImage: "mappin") }
                    if !encounter.place.isEmpty { Text(encounter.place) }
                }
                .font(.caption)
                .foregroundStyle(Palette.secondaryInk)

                if !encounter.note.isEmpty {
                    Text(encounter.note)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryInk)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                }
                FlowLayout(spacing: 10, lineSpacing: 6) {
                    if encounter.kind.isIntimate, encounter.protectionStatus.isRecorded {
                        Label(encounter.protectionStatus.compactLabel, systemImage: encounter.protectionStatus.symbolName)
                            .foregroundStyle(encounter.protectionStatus.tint)
                    }
                    if !encounter.photoIDs.isEmpty { Label("\(encounter.photoIDs.count)", systemImage: "photo") }
                    if let cost = encounter.cost, cost > 0 { Text(Format.money(cost)) }
                    if encounter.kind.isIntimate, !encounter.activitySummary.isEmpty { Text(encounter.activitySummary) }
                    if encounter.kind.isIntimate, !encounter.climaxSummary.isEmpty { Text(encounter.climaxSummary) }
                    if encounter.kind.isIntimate, encounter.boundaryFeeling.needsFollowUp {
                        Label("边界待回看", systemImage: "exclamationmark.bubble")
                            .foregroundStyle(Palette.warning)
                    }
                    if encounter.hasPendingFollowUp {
                        Label("待跟进", systemImage: "checklist").foregroundStyle(Palette.warning)
                    }
                }
                .font(.caption)
                .foregroundStyle(Palette.secondaryInk)
            }
        }
        .padding(.vertical, 10)
    }
}
