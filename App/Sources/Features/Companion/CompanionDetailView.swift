import SwiftUI

/// 单个对象详情：相处状态、边界与安全、亲密记录和快捷入口。
struct CompanionDetailView: View {

    let companionID: UUID

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showEditor = false
    @State private var editingEncounter: Encounter?
    @State private var showDeleteConfirm = false
    @State private var viewingPhotoIndex: Int?

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
        .sheet(item: $editingEncounter) { encounter in
            EncounterEditor(encounter: encounter)
        }
        .confirmationDialog(
            "删除这条档案？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除对象及全部记录", role: .destructive) {
                app.delete(companionID: companionID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("连同约过的记录和照片一起删掉，回不来。")
        }
        .sheet(isPresented: Binding(
            get: { viewingPhotoIndex != nil },
            set: { if !$0 { viewingPhotoIndex = nil } }
        )) {
            PhotoViewer(ids: app.albumIDs(for: companionID), index: viewingPhotoIndex ?? 0)
        }
    }

    // MARK: 内容

    private func content(_ companion: Companion) -> some View {
        List {
            if companion.isArchived {
                Section {
                    Label("已归档，不计入猎场和名册", systemImage: "archivebox.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            headerSection(companion)
            quickActionsSection(companion)
            albumSection(companion)
            if let overdueNote = overdueNote(companion) {
                Section {
                    Label(overdueNote, systemImage: "bell.badge.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
            }
            relationshipSection(companion)
            if hasIntimacyNotes(companion) {
                intimacyInfoSection(companion)
            }
            infoSection(companion)
            timelineSection(companion)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(app.namesRevealed ? companion.displayName : "猎获档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 头部

    private func headerSection(_ companion: Companion) -> some View {
        Section {
            VStack(spacing: 10) {
                AvatarView(companion: companion, size: 84)

                MaskedName(
                    name: companion.displayName,
                    revealed: app.namesRevealed,
                    font: .title2.weight(.bold)
                )

                HStack(spacing: 8) {
                    StageBadge(stage: companion.stage, filled: true)
                    Label(app.cityName(for: companion), systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let hookups = app.hookupCount(for: companion.id)
                let overnight = app.overnightCount(for: companion.id)
                let photos = app.albumIDs(for: companion.id).count
                if hookups >= 3 {
                    Text("回头客")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.coral, in: Capsule())
                }

                HStack(spacing: 8) {
                    huntStat("约成", "\(hookups)", Palette.coral)
                    huntStat("过夜", "\(overnight)", Color(red: 0.58, green: 0.34, blue: 0.92))
                    huntStat("照片", "\(photos)", Palette.accent)
                    huntStat(
                        "最近",
                        app.lastHookup(for: companion.id).map { Format.relativeDay($0.date) } ?? "—",
                        Palette.warning
                    )
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: 快捷记录

    private func quickActionsSection(_ companion: Companion) -> some View {
        Section {
            HStack(spacing: 10) {
                quickAction("flame.fill", "约成") {
                    editingEncounter = Encounter(companionID: companion.id, kind: .intimacy, cityID: companion.cityID)
                }
                quickAction("moon.fill", "过夜") {
                    editingEncounter = Encounter(companionID: companion.id, kind: .overnight, cityID: companion.cityID)
                }
                quickAction("person.2.fill", "见面") { app.logQuickContact(for: companion, kind: .meet) }
                quickAction("heart.text.square.fill", "聊骚") {
                    editingEncounter = Encounter(companionID: companion.id, kind: .flirting, cityID: companion.cityID)
                }
            }
            .padding(.vertical, 4)

            Button {
                Haptics.shared.play(.lightTap)
                editingEncounter = Encounter(companionID: companion.id, kind: .intimacy, cityID: companion.cityID)
            } label: {
                Label("记细节 / 留照片", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .tint(Palette.accent)
        } header: {
            Text("刚发生了什么？")
        }
    }

    private func quickAction(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .glassCard(cornerRadius: 14, interactive: true, shadowRadius: 6)
        }
        .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.95))
    }

    private func huntStat(_ caption: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func albumSection(_ companion: Companion) -> some View {
        let ids = app.albumIDs(for: companion.id)
        return Group {
            if !ids.isEmpty {
                Section {
                    if app.namesRevealed {
                        PhotoStrip(
                            ids: ids,
                            onOpen: { viewingPhotoIndex = $0 }
                        )
                    } else {
                        Label("点右上角眼睛再看照片", systemImage: "eye.slash")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("私藏")
                } footer: {
                    Text("头像和每次留下的照片都在这儿，只存在这台手机。")
                }
            }
        }
    }

    // MARK: 相处

    private func relationshipSection(_ companion: Companion) -> some View {
        Section("怎么约") {
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

            HStack {
                Text("默契度")
                Spacer()
                RatingPicker(
                    rating: Binding(
                        get: { companion.rating },
                        set: { app.setRating($0, for: companion) }
                    ),
                    size: 22
                )
            }
        }
    }

    // MARK: 边界与安全

    private func intimacyInfoSection(_ companion: Companion) -> some View {
        Section("说过的规矩") {
            if !companion.expectations.isEmpty {
                privateNoteRow("怎么约", symbol: "text.bubble.fill", text: companion.expectations, tint: Palette.accent)
            }
            if !companion.boundaries.isEmpty {
                privateNoteRow("她说过不行的", symbol: "hand.raised.fill", text: companion.boundaries, tint: Palette.warning)
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
        }
    }

    // MARK: 时间线

    private func timelineSection(_ companion: Companion) -> some View {
        Section {
            let encounters = app.encounters(for: companion.id)
            if encounters.isEmpty {
                Text("还没记过。上面四个按钮，点一下就行。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(encounters.prefix(30)) { encounter in
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
                            app.delete(encounterID: encounter.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("全部记录")
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

    @Environment(AppState.self) private var app

    private var companion: Companion? { app.companion(id: encounter.companionID) }
    private var cityName: String? {
        encounter.cityID.flatMap { app.city(id: $0)?.name }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(encounter.kind.tint.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: encounter.kind.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(encounter.kind.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if showName, let companion {
                        MaskedName(
                            name: companion.displayName,
                            revealed: app.namesRevealed,
                            font: .subheadline.weight(.semibold)
                        )
                    }
                    Text(encounter.kind.label)
                        .font(.subheadline)
                        .foregroundStyle(showName ? .secondary : .primary)
                    if !encounter.place.isEmpty {
                        Text("· \(encounter.place)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Text(Format.relativeDay(encounter.date))
                    if let cityName {
                        Label(cityName, systemImage: "mappin")
                    }
                    if encounter.kind.isIntimate, encounter.protectionStatus.isRecorded {
                        Label(encounter.protectionStatus.compactLabel, systemImage: encounter.protectionStatus.symbolName)
                            .foregroundStyle(encounter.protectionStatus.tint)
                    }
                    if !encounter.photoIDs.isEmpty {
                        Label("\(encounter.photoIDs.count)", systemImage: "photo")
                    }
                    if let cost = encounter.cost, cost > 0 {
                        Label(Format.money(cost), systemImage: "yensign.circle")
                    }
                    if !encounter.note.isEmpty {
                        Text("· \(encounter.note)")
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if encounter.kind.isIntimate,
                   !encounter.activities.isEmpty || encounter.boundaryFeeling.needsFollowUp || encounter.hasPendingFollowUp {
                    HStack(spacing: 6) {
                        if !encounter.activities.isEmpty {
                            Text(encounter.activitySummary)
                                .lineLimit(1)
                        }
                        if encounter.boundaryFeeling.needsFollowUp {
                            Label("边界待回看", systemImage: "exclamationmark.bubble.fill")
                                .foregroundStyle(Palette.warning)
                        }
                        if encounter.hasPendingFollowUp {
                            Label("待跟进", systemImage: "checklist")
                                .foregroundStyle(Palette.warning)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if encounter.kind.isConversation,
                   !encounter.conversationSummary.isEmpty
                    || !encounter.digitalBoundaries.isEmpty
                    || !encounter.conversationSafetyFlags.isEmpty
                    || encounter.hasPendingFollowUp {
                    HStack(spacing: 6) {
                        if !encounter.conversationSummary.isEmpty {
                            Text(encounter.conversationSummary)
                                .lineLimit(1)
                        }
                        if !encounter.digitalBoundaries.isEmpty {
                            Label("隐私已聊", systemImage: "hand.raised.fill")
                                .foregroundStyle(Palette.accent)
                        }
                        if !encounter.conversationSafetyFlags.isEmpty {
                            Label("账号安全待留意", systemImage: "lock.shield.fill")
                                .foregroundStyle(Palette.warning)
                        }
                        if encounter.hasPendingFollowUp {
                            Label("待跟进", systemImage: "checklist")
                                .foregroundStyle(Palette.warning)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
