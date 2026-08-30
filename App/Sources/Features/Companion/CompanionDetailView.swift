import SwiftUI

/// 单条档案详情：全部信息 + 相处时间线 + 快捷记录
struct CompanionDetailView: View {

    let companionID: UUID

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showEditor = false
    @State private var editingEncounter: Encounter?
    @State private var showDeleteConfirm = false

    private var companion: Companion? { app.companion(id: companionID) }

    var body: some View {
        Group {
            if let companion {
                content(companion)
            } else {
                EmptyStateView(symbol: "person.crop.circle.badge.questionmark", title: "档案不存在", message: "它可能已经被删除了。")
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
                                companion.isArchived ? "移出档案库" : "归档",
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
            Button("删除档案及全部记录", role: .destructive) {
                app.delete(companionID: companionID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("连同相处记录一起删除，且无法恢复。")
        }
    }

    // MARK: 内容

    private func content(_ companion: Companion) -> some View {
        List {
            if companion.isArchived {
                Section {
                    Label("已归档，不会出现在地图和名单里", systemImage: "archivebox.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            headerSection(companion)
            quickActionsSection(companion)
            if let overdueNote = overdueNote(companion) {
                Section {
                    Label(overdueNote, systemImage: "bell.badge.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
            }
            relationshipSection(companion)
            infoSection(companion)
            timelineSection(companion)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(companion.displayName)
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
                quickAction("message.fill", "聊了") { app.logQuickContact(for: companion, kind: .chat) }
                quickAction("phone.fill", "通话") { app.logQuickContact(for: companion, kind: .call) }
                quickAction("person.2.fill", "见了") { app.logQuickContact(for: companion, kind: .meet) }
                quickAction("gift.fill", "送礼") { app.logQuickContact(for: companion, kind: .gift) }
            }
            .padding(.vertical, 4)

            Button {
                Haptics.shared.play(.lightTap)
                editingEncounter = Encounter(companionID: companion.id, cityID: companion.cityID)
            } label: {
                Label("记一笔（带细节）", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .tint(Palette.accent)
        } header: {
            Text("刚发生过什么？")
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

    // MARK: 关系

    private func relationshipSection(_ companion: Companion) -> some View {
        Section("关系") {
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
                Text("心动指数")
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

    // MARK: 信息

    private func infoSection(_ companion: Companion) -> some View {
        Section("信息") {
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
                Text("还没有相处记录，用上面的按钮记一笔吧。")
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
            Text("相处记录")
        }
    }

    private func overdueNote(_ companion: Companion) -> String? {
        guard app.isOverdue(companion), let interval = companion.reminderIntervalDays else { return nil }
        return "超过 \(interval) 天没互动了，要不要联系一下？"
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
                        Text(companion.displayName)
                            .font(.subheadline.weight(.semibold))
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
            }
        }
        .padding(.vertical, 2)
    }
}
