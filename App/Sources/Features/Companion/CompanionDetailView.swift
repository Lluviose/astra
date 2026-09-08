import SwiftUI
import UIKit

/// 猎获档案：封面、见她之前看一眼、战绩小结、照片、评分、线索和她的时间线。
struct CompanionDetailView: View {

    let companionID: UUID

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showEditor = false
    @State private var editingEncounter: Encounter?
    @State private var showDeleteConfirm = false
    @State private var viewingPhotoIndex: Int?
    @State private var viewingPhotoIDs: [String] = []
    @State private var photoShelf: PhotoShelf = .album
    @State private var copiedContact = false

    private enum PhotoShelf: String, CaseIterable, Identifiable {
        case album
        case profile

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
                    Label("已归档，不计入猎场和名册", systemImage: "archivebox.fill")
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
            if companion.hasPlaybook {
                playbookSection(companion)
            }
            if app.hookupCount(for: companion.id) > 0 {
                recordSection(companion)
            }
            photosSection(companion)
            relationshipSection(companion)
            scoreSection(companion)
            infoSection(companion)
            timelineSection(companion)
        }
        .listStyle(.insetGrouped)
        .astraListBackground()
        .navigationTitle(app.namesRevealed ? companion.displayName : "档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 封面

    private func heroSection(_ companion: Companion) -> some View {
        let hookups = app.hookupCount(for: companion.id)
        let missed = app.missedCount(for: companion.id)
        let photos = app.albumIDs(for: companion.id).count
        let storyline = storylineText(companion)
        return Section {
            HeroPanel(
                gradient: Palette.dossierGradient(companion.paletteIndex),
                cornerRadius: 26,
                glow: Palette.avatarColors(companion.paletteIndex)[1],
                padding: 18
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        AvatarView(companion: companion, size: 72, showRing: false)

                        VStack(alignment: .leading, spacing: 6) {
                            MaskedName(
                                name: companion.displayName,
                                revealed: app.namesRevealed,
                                font: .title2.weight(.bold)
                            )
                            HStack(spacing: 6) {
                                StageBadge(stage: companion.stage, filled: true)
                                if hookups >= 3 {
                                    TagLabel(title: "回头客", systemImage: "arrow.triangle.2.circlepath", tint: Palette.gold, filled: true)
                                }
                            }
                            Label(app.locationName(for: companion), systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.76))
                            if let storyline {
                                Label(storyline, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.76))
                            }
                        }
                        Spacer(minLength: 0)
                        if companion.overallScore > 0 {
                            ScoreRing(score: companion.overallScore, size: 54)
                        }
                    }

                    HStack(spacing: 8) {
                        HeroMetric(value: "\(hookups)", label: "上床")
                        HeroMetric(value: "\(missed)", label: "没上")
                        HeroMetric(value: "\(photos)", label: "私藏")
                        HeroMetric(
                            value: app.lastHookup(for: companion.id).map { Format.relativeDay($0.date) } ?? "—",
                            label: "上次上床"
                        )
                    }

                    GlassStack(spacing: 10) {
                        HStack(spacing: 10) {
                            HeroButton(title: "上床了", systemImage: EncounterKind.intimacy.symbolName, prominent: true, cue: .waveSent) {
                                editingEncounter = Encounter(companionID: companion.id, kind: .intimacy, cityID: companion.cityID)
                            }
                            HeroButton(title: "没上床", systemImage: EncounterKind.missed.symbolName) {
                                editingEncounter = Encounter(companionID: companion.id, kind: .missed, cityID: companion.cityID)
                            }
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } footer: {
            Text("只选有没有上床；时间、地点和细节在下一页补。")
        }
    }

    /// 「认识 120 天 · 第 9 天上床」这类一句话；没记认识日期就只说上床。
    private func storylineText(_ companion: Companion) -> String? {
        let insights = app.companionInsights(for: companion.id)
        var parts: [String] = []
        if let days = companion.daysKnown() {
            parts.append("认识 \(days) 天")
        }
        if let daysToFirst = daysFromMeetingToFirstHookup(companion, insights: insights) {
            parts.append(daysToFirst == 0 ? "当天就上床" : "第 \(daysToFirst) 天上床")
        } else if let first = insights.firstHookupDate {
            parts.append("\(Format.relativeDay(first)) 第一次")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func daysFromMeetingToFirstHookup(_ companion: Companion, insights: EncounterInsights) -> Int? {
        guard let met = companion.metDate, let first = insights.firstHookupDate, first >= met else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: met), to: calendar.startOfDay(for: first)).day
    }

    // MARK: 见她之前看一眼

    private func playbookSection(_ companion: Companion) -> some View {
        Section {
            if !companion.turnOns.isEmpty {
                privateNoteRow("她在床上喜欢", symbol: "heart.text.square.fill", text: companion.turnOns, tint: Palette.coral)
            }
            if !companion.approachNotes.isEmpty {
                privateNoteRow("怎么约她最顺", symbol: "message.badge.filled.fill", text: companion.approachNotes, tint: Palette.accent)
            }
            if !companion.expectations.isEmpty {
                privateNoteRow("她想怎么约", symbol: "text.bubble.fill", text: companion.expectations, tint: Palette.accent)
            }
            if !companion.boundaries.isEmpty {
                privateNoteRow("她说过不行的", symbol: "hand.raised.fill", text: companion.boundaries, tint: Palette.warning)
            }
            if !companion.safetyNotes.isEmpty {
                privateNoteRow("安全备忘", symbol: "checkmark.shield.fill", text: companion.safetyNotes, tint: Palette.safe)
            }
        } header: {
            Text("见她之前看一眼")
        } footer: {
            Text("她随时可以改主意，规矩每次仍要当面确认。")
        }
    }

    // MARK: 和她的战绩

    private func recordSection(_ companion: Companion) -> some View {
        let insights = app.companionInsights(for: companion.id)
        let encounters = app.encounters(for: companion.id)
        return Section {
            if let first = insights.firstHookupDate {
                LabeledContent("第一次上床", value: DateFormatter.dayFull.string(from: first))
            }
            if let rate = insights.hookupRate, insights.recordCount > 1 {
                LabeledContent("上床率", value: rate.formatted(.percent.precision(.fractionLength(0))))
            }
            if let days = insights.averageGapDays {
                LabeledContent("平均间隔", value: "\(Int(days.rounded())) 天")
            }
            if let minutes = insights.averageDurationMinutes {
                LabeledContent("平均多久", value: Encounter.durationText(minutes: Int(minutes.rounded())))
            }
            if let rounds = insights.averageRounds {
                LabeledContent("平均几轮", value: String(format: "%.1f 轮", rounds))
            }
            if let initiator = insights.dominantInitiator {
                LabeledContent("谁更主动") {
                    Label(initiator.label, systemImage: initiator.symbolName)
                        .foregroundStyle(Palette.coral)
                }
            }
            if !insights.topActivities.isEmpty {
                LabeledContent("最常做") {
                    Text(insights.topActivities.prefix(3).map(\.item.label).joined(separator: "、"))
                        .multilineTextAlignment(.trailing)
                }
            }
            if !insights.topClimaxDetails.isEmpty {
                LabeledContent("怎么收的") {
                    Text(insights.topClimaxDetails.prefix(3).map(\.item.label).joined(separator: "、"))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Palette.coral)
                }
            }
            if insights.protectionRecordedCount > 0 {
                LabeledContent("套") {
                    HStack(spacing: 6) {
                        Text("全程 \(insights.protectionCounts[.protected] ?? 0)")
                        if insights.barrierGapCount > 0 {
                            Text("· 没戴全 \(insights.barrierGapCount)")
                                .foregroundStyle(Palette.warning)
                        }
                    }
                }
            }
            if insights.spendRecordedCount > 0 {
                LabeledContent("花费合计", value: Format.money(insights.totalSpend))
            }
            if let physical = insights.averagePhysical {
                LabeledContent("身体感受", value: String(format: "%.1f / 5", physical))
            }
            if let part = insights.favoriteDayPart {
                LabeledContent("常在", value: "\(part.label) \(part.hoursLabel)")
            }
            if let bestID = insights.bestHookupID, let best = encounters.first(where: { $0.id == bestID }) {
                Button {
                    Haptics.shared.play(.selection)
                    editingEncounter = best
                } label: {
                    LabeledContent("最爽的一次") {
                        HStack(spacing: 5) {
                            Text("\(Format.relativeDay(best.date)) · \(best.physicalRating) 分")
                            ChevronHint()
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("和她的战绩")
        }
    }

    // MARK: 照片

    private func photosSection(_ companion: Companion) -> some View {
        let albumIDs = app.albumIDs(for: companion.id)
        let profileIDs = app.profilePhotoIDs(for: companion.id)
        let ids = photoShelf == .album ? albumIDs : profileIDs
        return Section {
            Picker("照片", selection: $photoShelf) {
                Text("艳照 \(albumIDs.count)").tag(PhotoShelf.album)
                Text("人物照 \(profileIDs.count)").tag(PhotoShelf.profile)
            }
            .pickerStyle(.segmented)

            if !ids.isEmpty {
                if app.namesRevealed {
                    PhotoStrip(
                        ids: ids,
                        editable: true,
                        onDelete: { id in
                            if photoShelf == .album {
                                app.removeAlbumPhoto(id, from: companion.id)
                            } else {
                                app.removeProfilePhoto(id, from: companion.id)
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
                if photoShelf == .album {
                    app.addAlbumPhotoIDs(importedIDs, to: companion.id)
                } else {
                    app.addProfilePhotoIDs(importedIDs, to: companion.id)
                }
            }
        } header: {
            Text("照片")
        } footer: {
            Text(
                photoShelf == .album
                    ? "艳照和每次留下的照片放这里，不限数量，原图保存。"
                    : "头像和普通人物照放这里，不会混进艳照。"
            )
        }
    }

    // MARK: 相处

    private func relationshipSection(_ companion: Companion) -> some View {
        Section("到哪一步了") {
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
                showEditor = true
            } label: {
                Label("调整六维评分", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
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

    // MARK: 私密备忘行

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
                Button {
                    UIPasteboard.general.string = companion.contactNote
                    Haptics.shared.play(.success)
                    copiedContact = true
                } label: {
                    LabeledContent("联系方式") {
                        HStack(spacing: 5) {
                            Text(companion.contactNote)
                                .lineLimit(1)
                            Image(systemName: copiedContact ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(copiedContact ? Palette.safe : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("点一下复制")
                .task(id: copiedContact) {
                    guard copiedContact else { return }
                    try? await Task.sleep(for: .seconds(1.6))
                    copiedContact = false
                }
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
                    Label("补几条线索：年龄、尺码、怎么认识的", systemImage: "square.and.pencil")
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
                Text("还没记过。上面两个按钮，点一下就行。")
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
                if encounters.count > 30 {
                    Text("只显示最近 30 条，更早的去时间线搜。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("和她的时间线")
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
                    Text(showTime ? Format.clockTime(encounter.date) : Format.relativeDay(encounter.date))
                    if let locationName {
                        Label(locationName, systemImage: "mappin")
                    }
                    if encounter.venueCategory != .notRecorded {
                        Text(encounter.venueCategory.label)
                            .lineLimit(1)
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
                   !encounter.activities.isEmpty
                    || !encounter.climaxDetails.isEmpty
                    || !encounter.rhythmSummary.isEmpty
                    || encounter.boundaryFeeling.needsFollowUp
                    || encounter.hasPendingFollowUp {
                    HStack(spacing: 6) {
                        if !encounter.rhythmSummary.isEmpty {
                            Text(encounter.rhythmSummary)
                                .lineLimit(1)
                                .foregroundStyle(Palette.accent)
                        }
                        if !encounter.activities.isEmpty {
                            Text(encounter.activitySummary)
                                .lineLimit(1)
                        }
                        if !encounter.climaxSummary.isEmpty {
                            Text(encounter.climaxSummary)
                                .lineLimit(1)
                                .foregroundStyle(Palette.coral)
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

                if !encounter.missedSummary.isEmpty {
                    Text(encounter.missedSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if encounter.kind.isMissed, encounter.hasPendingFollowUp {
                    Label("待跟进", systemImage: "checklist")
                        .font(.caption2)
                        .foregroundStyle(Palette.warning)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

