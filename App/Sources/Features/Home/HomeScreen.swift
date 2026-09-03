import SwiftUI

/// 猎场首页：战绩总览、快速记一笔、今夜焦点、待处理事项和四个入口。
struct HomeScreen: View {

    @Environment(AppState.self) private var app

    @State private var flow = RecordingFlow()
    @State private var path = NavigationPath()
    @State private var showMap = false
    @State private var quickLogTarget: Companion?
    @State private var followUpTarget: Encounter?

    /// 快速记一笔条：最近互动过的人排前面。
    private var quickLogCompanions: [Companion] {
        Array(
            app.currentCompanions
                .sorted { lhs, rhs in
                    if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                    return app.lastContact(for: lhs) > app.lastContact(for: rhs)
                }
                .prefix(8)
        )
    }

    private var recentEncounters: [Encounter] {
        app.timeline(limit: 4)
    }

    /// 首页焦点只使用用户自己明确记录的置顶、关系阶段和互动次数，不推断对方意愿。
    private var focusCompanion: Companion? {
        app.currentCompanions.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.stage.weight != rhs.stage.weight { return lhs.stage.weight > rhs.stage.weight }

            let leftHookups = app.hookupCount(for: lhs.id)
            let rightHookups = app.hookupCount(for: rhs.id)
            if leftHookups != rightHookups { return leftHookups > rightHookups }
            if lhs.overallScore != rhs.overallScore { return lhs.overallScore > rhs.overallScore }
            return app.lastContact(for: lhs) > app.lastContact(for: rhs)
        }.first
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Palette.screenGradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        hero

                        if !quickLogCompanions.isEmpty {
                            quickLogStrip
                        }

                        focusCard

                        if !app.pendingFollowUps.isEmpty || !app.needsAttention.isEmpty {
                            todoCard
                        }

                        entryGrid

                        safetyCard

                        if !recentEncounters.isEmpty {
                            recordsCard
                        }
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
            .navigationDestination(for: RoyalRoute.self) { _ in
                RoyalHallScreen()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        flow.beginAddingCompanion()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("加个人")
                }

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
        .recordingFlowSheets(flow)
        .sheet(item: $followUpTarget) { encounter in
            EncounterEditor(encounter: encounter)
        }
        .sheet(isPresented: $showMap) {
            MapScreen()
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        }
        .confirmationDialog(
            quickLogTitle,
            isPresented: Binding(
                get: { quickLogTarget != nil },
                set: { if !$0 { quickLogTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: quickLogTarget
        ) { companion in
            Button("上床了") { flow.record(.intimacy, for: companion) }
            Button("没上床") { flow.record(.missed, for: companion) }
            Button("打开档案") { path.append(companion.id) }
            Button("取消", role: .cancel) {}
        } message: { companion in
            Text(quickLogMessage(for: companion))
        }
        .onChange(of: app.royalHallRequestToken) { oldValue, newValue in
            guard newValue != oldValue else { return }
            path.append(RoyalRoute.hall)
        }
    }

    // MARK: - 首屏主卡

    private var hero: some View {
        let rank = app.royalRank
        return HeroPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    HeroBadge(title: "只在这台手机上")
                    Spacer()
                    Label("Lv.\(rank.level)", systemImage: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.gold)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(rank.title)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                    Text(monthLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    HeroMetric(value: "\(app.conqueredCompanions.count)", label: "女人")
                    HeroMetric(value: "\(app.stats.totalIntimacyCount)", label: "上床")
                    HeroMetric(value: "\(app.stats.repeatGirlCount)", label: "回头客")
                    HeroMetric(value: "\(app.conquestLocationCount)", label: "战绩地")
                }

                HStack(spacing: 10) {
                    Menu {
                        Button {
                            flow.begin(kind: .intimacy, app: app)
                        } label: {
                            Label("上床了", systemImage: EncounterKind.intimacy.symbolName)
                        }
                        Button {
                            flow.begin(kind: .missed, app: app)
                        } label: {
                            Label("没上床", systemImage: EncounterKind.missed.symbolName)
                        }
                    } label: {
                        HeroButtonLabel(title: "记一笔", systemImage: "plus.circle.fill", prominent: true)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        RoyalHallScreen()
                    } label: {
                        HeroButtonLabel(title: "王者殿堂", systemImage: "crown.fill")
                    }
                    .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))
                }

                Text("私藏 \(app.privateCollectionCount) 张 · 成就 \(rank.unlockedCount)/\(rank.totalCount) · 名册 \(app.stats.activeCount) 人")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var monthLine: String {
        if app.stats.intimaciesThisMonth == 0,
           app.stats.missedThisMonth == 0,
           app.stats.girlsThisMonth == 0 {
            return "这个月还没动笔。上床或没上床，都记进时间线。"
        }
        var parts: [String] = []
        if app.stats.girlsThisMonth > 0 { parts.append("新人 \(app.stats.girlsThisMonth)") }
        parts.append("上床 \(app.stats.intimaciesThisMonth)")
        if app.stats.missedThisMonth > 0 { parts.append("没上 \(app.stats.missedThisMonth)") }
        if app.stats.photosThisMonth > 0 { parts.append("照片 \(app.stats.photosThisMonth)") }
        return "本月：" + parts.joined(separator: " · ")
    }

    // MARK: - 快速记一笔

    private var quickLogStrip: some View {
        SectionCard("点她，直接记", systemImage: "hand.tap.fill", tint: Palette.coral) {
            Text("最近的人")
        } content: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(quickLogCompanions) { companion in
                        Button {
                            Haptics.shared.play(.selection)
                            quickLogTarget = companion
                        } label: {
                            VStack(spacing: 6) {
                                AvatarView(companion: companion, size: 54)
                                MaskedName(
                                    name: companion.displayName,
                                    revealed: app.namesRevealed,
                                    font: .caption2.weight(.semibold)
                                )
                                .frame(width: 62)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.94))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var quickLogTitle: String {
        guard let companion = quickLogTarget else { return "" }
        return app.namesRevealed ? "和\(companion.displayName)，这次怎么样？" : "这次怎么样？"
    }

    private func quickLogMessage(for companion: Companion) -> String {
        let hookups = app.hookupCount(for: companion.id)
        let last = app.lastContact(for: companion)
        return "\(companion.stage.label) · 上床 \(hookups) 次 · 最近 \(Format.relativeDay(last))"
    }

    // MARK: - 今夜焦点

    @ViewBuilder
    private var focusCard: some View {
        if let companion = focusCompanion {
            HeroPanel(gradient: Palette.velvetGradient, cornerRadius: 26, glow: Palette.coral, padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label(focusKicker, systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                        Spacer()
                        Label("按你的记录", systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    HStack(spacing: 14) {
                        AvatarView(companion: companion, size: 58)

                        VStack(alignment: .leading, spacing: 5) {
                            MaskedName(
                                name: companion.displayName,
                                revealed: app.namesRevealed,
                                font: .title3.weight(.bold)
                            )
                            Text(focusHeadline(for: companion))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        focusPill(companion.stage.label, symbol: companion.stage.symbolName)
                        if companion.overallScore > 0 {
                            focusPill("综合 \(companion.overallScore)", symbol: "crown.fill")
                        }
                        focusPill("上床 \(app.hookupCount(for: companion.id))", symbol: "flame.fill")
                        let photoCount = app.albumIDs(for: companion.id).count
                        if photoCount > 0 {
                            focusPill("私藏 \(photoCount)", symbol: "photo.fill")
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("升温轨迹")
                            Spacer()
                            Text(focusRecency(for: companion))
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))

                        ProgressView(value: Double(companion.stage.weight), total: 7)
                            .tint(.white)
                    }

                    HStack(spacing: 10) {
                        NavigationLink(value: companion.id) {
                            HeroButtonLabel(title: "打开档案", systemImage: "book.pages.fill")
                        }
                        .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))

                        HeroButton(title: "记录结果", systemImage: "plus.circle.fill", prominent: true, cue: .waveSent) {
                            quickLogTarget = companion
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("下一次，从一个名字开始", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Palette.coral)
                Text("先记下一个她。等关系升温、留下记录，这里会把最值得回味和推进的人放到前面。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    flow.beginAddingCompanion()
                } label: {
                    Label("加第一个人", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.accent.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(HapticButtonStyle(cue: .mediumTap, scale: 0.97))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(cornerRadius: 22, shadowRadius: 10)
        }
    }

    private var focusKicker: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 18 || hour < 5) ? "今夜焦点" : "下一次焦点"
    }

    private func focusHeadline(for companion: Companion) -> String {
        switch companion.stage {
        case .regular, .casual:
            return "熟悉的默契还在，打开档案就能回到上一次。"
        case .prospect:
            return "已经是准炮友了，下一步先确认彼此今晚想要什么。"
        case .flirting:
            return "暧昧正在升温，欲望和边界都值得记清楚。"
        case .chatting, .new:
            return "故事刚开场，把节奏推到你们都舒服的位置。"
        case .paused, .ended:
            return "这段记录先留在册子里。"
        }
    }

    private func focusRecency(for companion: Companion) -> String {
        if let last = app.lastHookup(for: companion.id) {
            return "上次上床 \(Format.relativeDay(last.date))"
        }
        return "最近互动 \(Format.relativeDay(app.lastContact(for: companion)))"
    }

    private func focusPill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.black.opacity(0.16), in: Capsule())
            .foregroundStyle(.white.opacity(0.84))
    }

    // MARK: - 待处理

    private var todoCard: some View {
        let followUps = Array(app.pendingFollowUps.prefix(3))
        let attention = Array(app.needsAttention.prefix(3))
        return SectionCard("待处理", systemImage: "bell.badge.fill", tint: Palette.warning) {
            Text("\(app.pendingFollowUps.count + app.needsAttention.count) 项")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(followUps) { encounter in
                    Button {
                        Haptics.shared.play(.selection)
                        followUpTarget = encounter
                    } label: {
                        FollowUpRow(encounter: encounter)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if !followUps.isEmpty, !attention.isEmpty {
                    Divider()
                }

                ForEach(attention) { companion in
                    NavigationLink(value: companion.id) {
                        HStack(spacing: 11) {
                            AvatarView(companion: companion, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                                Text("到了联系周期 · \(Format.silence(days: app.daysSinceContact(for: companion)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ChevronHint()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 四个入口

    private var entryGrid: some View {
        let rank = app.royalRank
        let next = AchievementCatalog.nextUp(in: app.achievements, limit: 1).first
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            NavigationLink {
                HaremGalleryScreen()
            } label: {
                EntryTile(
                    title: "后宫图鉴",
                    subtitle: app.conqueredCompanions.isEmpty
                        ? "上过的才会进来"
                        : "\(app.conqueredCompanions.count) 个她 · 私藏 \(app.privateCollectionCount) 张",
                    systemImage: "crown.fill",
                    tint: Palette.coral
                )
            }
            .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))

            NavigationLink {
                AchievementsScreen()
            } label: {
                EntryTile(
                    title: "成就册",
                    subtitle: next.map { "已点亮 \(rank.unlockedCount)/\(rank.totalCount) · 下一枚：\($0.title)" }
                        ?? (rank.totalCount > 0 ? "全册点亮了" : "记下第一个她就翻开"),
                    systemImage: "medal.fill",
                    tint: Palette.goldDeep
                )
            }
            .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))

            NavigationLink {
                InsightsScreen()
            } label: {
                EntryTile(
                    title: "战绩统计",
                    subtitle: insightsSubtitle,
                    systemImage: "chart.bar.xaxis",
                    tint: Palette.accent
                )
            }
            .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))

            Button {
                showMap = true
            } label: {
                EntryTile(
                    title: "猎场版图",
                    subtitle: app.buckets.isEmpty
                        ? "还没点亮地点"
                        : "\(app.conquestLocationCount) 处战绩地 · 头号 \(app.topConquestBucket?.city.name ?? "—")",
                    systemImage: "map.fill",
                    tint: Palette.safe
                )
            }
            .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))
        }
    }

    private var insightsSubtitle: String {
        let insights = app.insights
        if insights.isEmpty { return "记几笔就有数了" }
        var parts = ["上床率 \(rateText(insights.hookupRate))"]
        if let part = insights.favoriteDayPart { parts.append("偏爱\(part.label)") }
        return parts.joined(separator: " · ")
    }

    private func rateText(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return rate.formatted(.percent.precision(.fractionLength(0)))
    }

    // MARK: - 安全小结

    private var safetyCard: some View {
        SectionCard("安全小结", systemImage: "checkmark.shield.fill", tint: Palette.safe) {
            Text("不做评判，只帮你记住")
        } content: {
            if app.stats.intimaciesThisMonth == 0 {
                Label("上床的时候，顺手记一下有没有戴套。", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    Text("本月上床 \(app.stats.intimaciesThisMonth) 次，套记了 \(app.stats.safetyRecordedThisMonth) 次")
                        .font(.subheadline.weight(.semibold))

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

    // MARK: - 最近记录

    private var recordsCard: some View {
        SectionCard("最近记录", systemImage: "clock.arrow.circlepath", tint: Palette.coral) {
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
}
