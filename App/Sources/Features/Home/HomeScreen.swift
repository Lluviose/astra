import SwiftUI

/// A quiet daily overview: record first, then recent people and memories.
struct HomeScreen: View {

    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AstraLayout.sectionSpacing) {
                    masthead
                    overview
                    if !quickLogCompanions.isEmpty { quickLogStrip }
                    if !app.pendingFollowUps.isEmpty || !app.needsAttention.isEmpty { todoCard }
                    if !recentEncounters.isEmpty { recordsCard }
                    entryGrid
                    if let companion = focusCompanion { focusRow(companion) }
                    if app.stats.intimaciesThisMonth > 0 { safetyCard }
                    Label("属于你的私人记录", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, AstraLayout.gutter)
                .padding(.bottom, 24)
                .astraContentMargins()
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("星图")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                CompanionDetailView(companionID: id)
            }
            .navigationDestination(for: RoyalRoute.self) { _ in RoyalHallScreen() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("ASTRA")
                        .font(.caption.weight(.semibold).monospaced())
                        .tracking(3)
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.toggleNamesRevealed() } label: {
                        Image(systemName: app.namesRevealed ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(app.namesRevealed ? "隐藏代号" : "显示代号")
                    .accessibilityIdentifier("privacy-toggle")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { flow.beginAddingCompanion() } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("添加档案")
                }
            }
        }
        .recordingFlowSheets(flow)
        .sheet(item: $followUpTarget) { EncounterEditor(encounter: $0) }
        .sheet(isPresented: $showMap) {
            MapScreen().presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "记录这次相处",
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
        }
        .onChange(of: app.royalHallRequestToken) { oldValue, newValue in
            guard newValue != oldValue else { return }
            path.append(RoyalRoute.hall)
        }
    }

    private var masthead: some View {
        HStack(alignment: .center, spacing: 16) {
            PageMasthead(
                eyebrow: Date().formatted(.dateTime.month(.wide).day().weekday(.wide)),
                title: "留住，属于你的片刻。",
                subtitle: app.isEmpty ? "从一个名字，开始你的私人记忆。" : "人物、相处与足迹，在这里慢慢珍藏。"
            )
        }
    }

    private var overview: some View {
        HeroPanel {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("PERSONAL JOURNAL")
                            .font(.caption2.monospaced())
                            .tracking(2)
                            .foregroundStyle(Palette.gold)
                        Text(app.isEmpty ? "你的故事，待续" : "记忆正在生长")
                            .font(.system(.title2, design: .serif))
                    }
                    Spacer(minLength: 10)
                    AstraMark()
                }

                if !app.isEmpty {
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                    layout {
                        QuietMetric(value: "\(app.stats.activeCount)", label: "在册人物", onDark: true)
                        QuietMetric(value: "\(app.encounters.count)", label: "相处记录", onDark: true)
                        QuietMetric(value: "\(app.stats.cityCount)", label: "足迹地点", onDark: true)
                    }
                } else {
                    Text("记下相识与每次相处。时间、地点和感受，都有自己的位置。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    flow.begin(kind: .intimacy, app: app)
                } label: {
                    PrimaryActionLabel(title: app.isEmpty ? "开始第一篇记录" : "记一笔", systemImage: "square.and.pencil", onDark: true)
                }
                .buttonStyle(HapticButtonStyle())
                .accessibilityIdentifier("home-record")

                NavigationLink {
                    RoyalHallScreen()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown").foregroundStyle(Palette.gold)
                        Text("Lv.\(app.royalRank.level) · \(app.royalRank.title)")
                        Spacer()
                        Text("殿堂")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quickLogStrip: some View {
        SectionCard("最近的人", systemImage: "person.crop.circle", trailing: {
            Text("轻点记录")
        }) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(quickLogCompanions) { companion in
                        Button { quickLogTarget = companion } label: {
                            VStack(spacing: 10) {
                                AvatarView(companion: companion, size: 56, showRing: false)
                                MaskedName(name: companion.displayName, revealed: app.namesRevealed, font: .caption)
                                    .frame(width: typeSize.isAccessibilitySize ? 104 : 68)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HapticButtonStyle())
                        .accessibilityLabel(app.namesRevealed ? "记录与\(companion.displayName)的相处" : "记录与隐藏人物的相处")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func focusRow(_ companion: Companion) -> some View {
        SectionCard("回到一段记忆", systemImage: "bookmark") {
            NavigationLink(value: companion.id) {
                HStack(spacing: 14) {
                    AvatarView(companion: companion, size: 52, showRing: false)
                    VStack(alignment: .leading, spacing: 6) {
                        MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                        Text("\(companion.stage.label) · \(Format.relativeDay(app.lastContact(for: companion)))")
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryInk)
                    }
                    Spacer()
                    ChevronHint()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var entryGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("慢慢翻阅")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 150), spacing: 12)], spacing: 12) {
                NavigationLink { HaremGalleryScreen() } label: {
                    EntryTile(title: "私人图鉴", subtitle: "\(app.conqueredCompanions.count) 位人物 · \(app.privateCollectionCount) 张私藏", systemImage: "rectangle.stack", tint: Palette.coral)
                }
                NavigationLink { InsightsScreen() } label: {
                    EntryTile(title: "相处统计", subtitle: "在时间里发现自己的节奏", systemImage: "chart.xyaxis.line", tint: Palette.safe)
                }
                Button { showMap = true } label: {
                    EntryTile(title: "足迹地图", subtitle: "\(app.conquestLocationCount) 处记录里的地点", systemImage: "map", tint: Palette.safe)
                }
                .accessibilityIdentifier("home-map")
                NavigationLink { AchievementsScreen() } label: {
                    EntryTile(title: "成就收藏", subtitle: "已点亮 \(app.royalRank.unlockedCount) / \(app.royalRank.totalCount)", systemImage: "seal", tint: Palette.accent)
                }
            }
            .buttonStyle(HapticButtonStyle(scale: 0.98))
        }
    }

    private var recordsCard: some View {
        SectionCard("最近记录", systemImage: "clock") {
            ForEach(Array(recentEncounters.enumerated()), id: \.element.id) { index, encounter in
                if app.companion(id: encounter.companionID) != nil {
                    Button { followUpTarget = encounter } label: {
                        EncounterRow(encounter: encounter)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("打开并编辑这条记录")
                    if index < recentEncounters.count - 1 { Divider().padding(.leading, 48) }
                }
            }
        }
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

    // MARK: - 安全小结

    private var safetyCard: some View {
        SectionCard("安全小结", systemImage: "checkmark.shield.fill", tint: Palette.safe) {
            Text("本月")
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

}
