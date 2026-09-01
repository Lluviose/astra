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

    private var haremPreviewCompanions: [Companion] {
        Array(app.conqueredCompanions.prefix(5))
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
        NavigationStack {
            ZStack {
                Palette.screenGradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 18) {
                        hero

                        NavigationLink {
                            HaremGalleryScreen()
                        } label: {
                            haremPreviewCard
                        }
                        .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.985))

                        NavigationLink {
                            AchievementsScreen()
                        } label: {
                            AchievementPreviewRow(achievements: app.achievements)
                        }
                        .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.98))

                        desirePulseCard

                        if !app.pendingFollowUps.isEmpty {
                            followUpCard
                        }

                        if !app.needsAttention.isEmpty {
                            attentionCard
                        }

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
                        Haptics.shared.play(.lightTap)
                        beginAddingCompanion()
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
                Label("私人记录 · 可随设备备份", systemImage: "lock.shield.fill")
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
                Text("后宫王者战绩")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                Text(monthLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                heroMetric(value: "\(app.conqueredCompanions.count)", label: "女人")
                heroMetric(value: "\(app.stats.totalIntimacyCount)", label: "上床")
                heroMetric(value: "\(app.stats.repeatGirlCount)", label: "回头客")
                heroMetric(value: "\(app.conquestCityCount)", label: "战绩城")
            }

            HStack(spacing: 10) {
                Menu {
                    Button {
                        beginRecording(kind: .intimacy)
                    } label: {
                        Label("上床了", systemImage: EncounterKind.intimacy.symbolName)
                    }
                    Button {
                        beginRecording(kind: .missed)
                    } label: {
                        Label("没上床", systemImage: EncounterKind.missed.symbolName)
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
                    Haptics.shared.play(.cityFocus)
                    showMap = true
                } label: {
                    Label("巡视版图", systemImage: "map.fill")
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

            Text("私藏 \(app.privateCollectionCount) 张 · 成就 \(app.achievements.filter(\.isUnlocked).count)/\(app.achievements.count) · 名册 \(app.stats.activeCount)")
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
        return "本月战绩：" + parts.joined(separator: " · ")
    }

    // MARK: - 后宫图鉴预览

    private var haremPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("后宫图鉴", systemImage: "crown.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.coral)
                Spacer()
                Text(haremPreviewCompanions.isEmpty ? "等第一位" : "全部 \(app.conqueredCompanions.count) 位")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            if haremPreviewCompanions.isEmpty {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(Palette.coral.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: "crown")
                            .foregroundStyle(Palette.coral)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("第一位上过的女人，会站上这里")
                            .font(.subheadline.weight(.semibold))
                        Text("名册不算战绩；记录「上床了」才会进入图鉴。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(haremPreviewCompanions.enumerated()), id: \.element.id) { index, companion in
                            VStack(alignment: .leading, spacing: 7) {
                                ZStack(alignment: .topLeading) {
                                    HaremPortrait(
                                        companion: companion,
                                        photoID: haremCoverPhotoID(for: companion),
                                        height: 126,
                                        cornerRadius: 18
                                    )
                                    Text("#\(index + 1)")
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(index < 3 ? Color.black.opacity(0.78) : Color.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(
                                            index < 3
                                                ? AnyShapeStyle(Color(red: 1.0, green: 0.80, blue: 0.28).gradient)
                                                : AnyShapeStyle(Color.black.opacity(0.44)),
                                            in: Capsule()
                                        )
                                        .padding(8)
                                }

                                MaskedName(
                                    name: companion.displayName,
                                    revealed: app.namesRevealed,
                                    font: .caption.weight(.bold)
                                )
                                Label("上床 \(app.hookupCount(for: companion.id))", systemImage: "flame.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.coral)
                            }
                            .frame(width: 112, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "photo.stack.fill")
                Text("进去每天回味一个她，照片、次数、城市和排名都在。")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 24, interactive: true, shadowRadius: 12)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func haremCoverPhotoID(for companion: Companion) -> String? {
        app.profilePhotoIDs(for: companion.id).first
            ?? app.albumIDs(for: companion.id).first
    }

    // MARK: - 欲望与行动焦点

    @ViewBuilder
    private var desirePulseCard: some View {
        if let companion = focusCompanion {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(focusKicker, systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
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
                        Label("打开档案", systemImage: "book.pages.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.97))

                    Button {
                        beginRecording(.intimacy, with: companion)
                    } label: {
                        Label(
                            "记录结果",
                            systemImage: "plus.circle.fill"
                        )
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(Palette.accentDeep)
                    }
                    .buttonStyle(HapticButtonStyle(cue: .waveSent, scale: 0.97))
                }
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.055, blue: 0.23),
                        Color(red: 0.39, green: 0.08, blue: 0.32),
                        Color(red: 0.72, green: 0.15, blue: 0.32),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 150, height: 150)
                    .blur(radius: 4)
                    .offset(x: 62, y: -74)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Palette.coral.opacity(0.24), radius: 20, y: 10)
            .accessibilityElement(children: .contain)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("下一次，从一个名字开始", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Palette.coral)
                Text("先记下一个她。等关系升温、留下记录，首页会把最值得回味和推进的线索放到这里。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    beginAddingCompanion()
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
            return "已经到了准炮友，下一步先确认彼此今晚想要什么。"
        case .flirting:
            return "暧昧正在升温，欲望和边界都值得记清楚。"
        case .chatting, .new:
            return "故事刚开场，把节奏慢慢推到你们都舒服的位置。"
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
                Label("上床的时候，可以顺手记有没有戴套。", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("本月上床 \(app.stats.intimaciesThisMonth) 次，套记了 \(app.stats.safetyRecordedThisMonth) 次")
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
                    Text(
                        app.buckets.isEmpty
                            ? "还没点亮城市"
                            : "版图 \(app.conquestCityCount) 城 · \(app.conqueredCompanions.count) 个她 · 上床 \(app.stats.totalIntimacyCount)"
                    )
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

    /// 焦点卡已经确定对象，直接进入编辑器，省掉一次对象选择。
    private func beginRecording(_ kind: EncounterKind, with companion: Companion) {
        recordingKind = kind
        pendingCompanionSelection = nil
        recordAfterCreatingCompanion = false
        recordingCompanionID = nil
        newEncounter = Encounter(
            companionID: companion.id,
            kind: kind,
            cityID: companion.cityID
        )
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
