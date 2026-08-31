import SwiftUI

/// 产品首页：把记录入口、当前对象、安全小结和最近动态放在同一条主线上。
struct HomeScreen: View {

    @Environment(AppState.self) private var app

    @State private var isPickingCompanion = false
    @State private var isPickingCity = false
    @State private var editorTarget: Companion?
    @State private var newEncounter: Encounter?
    @State private var showMap = false
    @State private var recordingKind: EncounterKind = .intimacy
    @State private var pendingCompanionSelection: Companion?
    @State private var pendingCitySelection: City?
    @State private var recordAfterCreatingCompanion = false
    @State private var recordingCompanionID: UUID?

    private var recentCompanions: [Companion] {
        Array(
            app.currentCompanions
                .sorted { app.lastContact(for: $0) > app.lastContact(for: $1) }
                .prefix(4)
        )
    }

    private var recentEncounters: [Encounter] {
        app.timeline(limit: 4)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.screenGradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 18) {
                        hero

                        NavigationLink {
                            AchievementsScreen()
                        } label: {
                            AchievementPreviewRow(achievements: app.achievements)
                        }
                        .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.98))

                        if !app.pendingFollowUps.isEmpty {
                            followUpCard
                        }

                        if !app.needsAttention.isEmpty {
                            attentionCard
                        }

                        hottestCard

                        safetyCard

                        if !recentCompanions.isEmpty {
                            peopleCard
                        }

                        if !recentEncounters.isEmpty {
                            recordsCard
                        }

                        footprintCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("猎场")
            .navigationDestination(for: UUID.self) { id in
                CompanionDetailView(companionID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        app.toggleNamesRevealed()
                    } label: {
                        Image(systemName: app.namesRevealed ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(app.namesRevealed ? "隐藏代号" : "显示代号")
                }
            }
        }
        .sheet(isPresented: $isPickingCompanion, onDismiss: finishCompanionSelection) {
            CompanionPickerSheet { companion in
                pendingCompanionSelection = companion
            }
        }
        .sheet(item: $newEncounter) { encounter in
            EncounterEditor(encounter: encounter)
        }
        .sheet(isPresented: $isPickingCity, onDismiss: finishCitySelection) {
            CityPickerSheet(title: "常驻或常见面的城市") { city in
                pendingCitySelection = city
            }
        }
        .sheet(item: $editorTarget, onDismiss: finishCompanionEditor) { companion in
            CompanionEditor(companion: companion)
        }
        .sheet(isPresented: $showMap) {
            MapScreen()
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
    }

    // MARK: - 首屏主卡

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("记录册 · 仅存本机", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())

                Spacer()

                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.76))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("猎艳记录册")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                Text(monthLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                heroMetric(value: "\(app.stats.girlsThisMonth)", label: "新人")
                heroMetric(value: "\(app.stats.intimaciesThisMonth)", label: "约成")
                heroMetric(value: "\(app.stats.overnightThisMonth)", label: "过夜")
                heroMetric(value: "\(app.stats.photosThisMonth)", label: "照片")
            }

            HStack(spacing: 10) {
                Menu {
                    Button {
                        beginRecording(kind: .intimacy)
                    } label: {
                        Label("约成了", systemImage: EncounterKind.intimacy.symbolName)
                    }
                    Button {
                        beginRecording(kind: .overnight)
                    } label: {
                        Label("过夜", systemImage: EncounterKind.overnight.symbolName)
                    }
                    Button {
                        beginRecording(kind: .meet)
                    } label: {
                        Label("见面", systemImage: EncounterKind.meet.symbolName)
                    }
                    Button {
                        beginRecording(kind: .chat)
                    } label: {
                        Label("聊天", systemImage: EncounterKind.chat.symbolName)
                    }
                } label: {
                    Label("记一笔", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Palette.accentDeep)
                }

                Button {
                    Haptics.shared.play(.mediumTap)
                    beginAddingCompanion()
                } label: {
                    Label("加个人", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                        }
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Text("累计 名册 \(app.stats.activeCount) · 约成 \(app.stats.totalIntimacyCount) · 过夜 \(app.stats.overnightCount)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(Palette.heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.09))
                .frame(width: 170, height: 170)
                .blur(radius: 2)
                .offset(x: 70, y: -92)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Palette.accentDeep.opacity(0.28), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var monthLine: String {
        if app.stats.intimaciesThisMonth == 0, app.stats.girlsThisMonth == 0 {
            return "这个月还没动笔。约成、过夜、留照片，都写在这本册子里。"
        }
        var parts: [String] = []
        if app.stats.girlsThisMonth > 0 { parts.append("新人 \(app.stats.girlsThisMonth)") }
        parts.append("约成 \(app.stats.intimaciesThisMonth)")
        if app.stats.overnightThisMonth > 0 { parts.append("过夜 \(app.stats.overnightThisMonth)") }
        if app.stats.photosThisMonth > 0 { parts.append("照片 \(app.stats.photosThisMonth)") }
        return "本月猎获：" + parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var hottestCard: some View {
        if let id = app.stats.topCompanionID,
           let companion = app.companion(id: id) {
            let count = app.hookupCount(for: id)
            if count > 0 {
                NavigationLink(value: companion.id) {
                    HStack(spacing: 14) {
                        AvatarView(companion: companion, size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("猎获最多")
                                .font(.headline)
                            HStack(spacing: 6) {
                                MaskedName(name: companion.displayName, revealed: app.namesRevealed, font: .caption.weight(.semibold))
                                Text("约成 \(count) 次")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if count >= 3 {
                                    Text("回头客")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Palette.coral)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 22, interactive: true, shadowRadius: 10)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.98))
            }
        }
    }

    private func heroMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 待跟进

    private var followUpCard: some View {
        homeCard(title: "待跟进", symbol: "checklist", tint: Palette.warning) {
            ForEach(Array(app.pendingFollowUps.prefix(3).enumerated()), id: \.element.id) { index, encounter in
                Button {
                    Haptics.shared.play(.selection)
                    newEncounter = encounter
                } label: {
                    FollowUpRow(encounter: encounter)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < min(app.pendingFollowUps.count, 3) - 1 {
                    Divider().padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - 联系节奏

    private var attentionCard: some View {
        homeCard(title: "到了联系周期", symbol: "bell.badge.fill", tint: Palette.warning) {
            ForEach(Array(app.needsAttention.prefix(3))) { companion in
                NavigationLink(value: companion.id) {
                    HStack(spacing: 11) {
                        AvatarView(companion: companion, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                            Text(Format.silence(days: app.daysSinceContact(for: companion)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 安全小结

    private var safetyCard: some View {
        homeCard(title: "安全小结", symbol: "checkmark.shield.fill", tint: Palette.safe) {
            if app.stats.intimaciesThisMonth == 0 {
                Label("约成的时候，可以顺手记有没有戴套。", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("本月约成 \(app.stats.intimaciesThisMonth) 次，套记了 \(app.stats.safetyRecordedThisMonth) 次")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("不做评判，只帮你记住")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(
                        value: Double(app.stats.safetyRecordedThisMonth),
                        total: Double(max(app.stats.intimaciesThisMonth, 1))
                    )
                    .tint(Palette.safe)

                    if app.stats.unprotectedThisMonth > 0 {
                        Label(
                            "有 \(app.stats.unprotectedThisMonth) 次没戴全或没戴；要做检测的话，去那条记录里勾一下。",
                            systemImage: "exclamationmark.shield.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Palette.warning)
                    }
                }
            }
        }
    }

    // MARK: - 最近对象 / 记录

    private var peopleCard: some View {
        homeCard(title: "最近猎获", symbol: "person.2.fill", tint: Palette.accent) {
            ForEach(Array(recentCompanions.enumerated()), id: \.element.id) { index, companion in
                NavigationLink(value: companion.id) {
                    CompanionRow(companion: companion)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < recentCompanions.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
    }

    private var recordsCard: some View {
        homeCard(title: "最近记录", symbol: "clock.arrow.circlepath", tint: Palette.coral) {
            ForEach(Array(recentEncounters.enumerated()), id: \.element.id) { index, encounter in
                if app.companion(id: encounter.companionID) != nil {
                    NavigationLink(value: encounter.companionID) {
                        EncounterRow(encounter: encounter)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < recentEncounters.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
    }

    // MARK: - 城市足迹

    private var footprintCard: some View {
        Button {
            showMap = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.14))
                        .frame(width: 46, height: 46)
                    Image(systemName: "map.fill")
                        .foregroundStyle(Palette.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("猎场地图")
                        .font(.headline)
                    Text(app.buckets.isEmpty ? "还没点亮城市" : "\(app.buckets.count) 座城市 · \(app.currentCompanions.count) 个人")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .glassCard(cornerRadius: 22, interactive: true, shadowRadius: 10)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.98))
    }

    // MARK: - 组件

    private func homeCard<Content: View>(
        title: String,
        symbol: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 22, shadowRadius: 10)
    }

    private func beginRecording(kind: EncounterKind) {
        Haptics.shared.play(.lightTap)
        recordingKind = kind
        pendingCompanionSelection = nil
        if app.currentCompanions.isEmpty {
            recordAfterCreatingCompanion = true
            recordingCompanionID = nil
            pendingCitySelection = nil
            isPickingCity = true
        } else {
            recordAfterCreatingCompanion = false
            isPickingCompanion = true
        }
    }

    private func beginAddingCompanion() {
        recordAfterCreatingCompanion = false
        recordingCompanionID = nil
        pendingCitySelection = nil
        isPickingCity = true
    }

    private func finishCompanionSelection() {
        guard let companion = pendingCompanionSelection else { return }
        pendingCompanionSelection = nil
        newEncounter = Encounter(
            companionID: companion.id,
            kind: recordingKind,
            cityID: companion.cityID
        )
    }

    private func finishCitySelection() {
        guard let city = pendingCitySelection else {
            recordAfterCreatingCompanion = false
            recordingCompanionID = nil
            return
        }
        pendingCitySelection = nil

        let draft = app.makeDraftCompanion(cityID: city.id)
        if recordAfterCreatingCompanion {
            recordingCompanionID = draft.id
        }
        editorTarget = draft
    }

    private func finishCompanionEditor() {
        defer {
            recordAfterCreatingCompanion = false
            recordingCompanionID = nil
        }
        guard recordAfterCreatingCompanion,
              let companionID = recordingCompanionID,
              let companion = app.companion(id: companionID)
        else { return }

        newEncounter = Encounter(
            companionID: companion.id,
            kind: recordingKind,
            cityID: companion.cityID
        )
    }
}
