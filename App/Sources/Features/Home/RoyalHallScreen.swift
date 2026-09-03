import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum RoyalRoute: Hashable {
    case hall
}

struct RoyalHallScreen: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                throne
                customization
                entranceGrid
                records
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("王者殿堂")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var throne: some View {
        HeroPanel(
            gradient: app.royalProfile.bannerStyle.gradient,
            glow: Palette.goldDeep,
            watermark: "crown.fill"
        ) {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    HeroBadge(title: "私人王国", systemImage: app.royalProfile.bannerStyle.symbolName)
                    Spacer()
                    Label("Lv.\(app.royalRank.level)", systemImage: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.gold)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(app.selectedRoyalTitle)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                    if let capital = app.capitalTerritory {
                        Text("王都 · \(app.locationName(id: capital.locationID)) · \(capital.tier.label)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    } else {
                        Text("册封一处战绩地为王都，让版图真正属于你。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }

                HStack(spacing: 8) {
                    HeroMetric(value: "\(app.conqueredCompanions.count)", label: "女人")
                    HeroMetric(value: "\(app.stats.totalIntimacyCount)", label: "上床")
                    HeroMetric(value: "\(app.stats.repeatGirlCount)", label: "回头客")
                    HeroMetric(value: "\(app.conquestLocationCount)", label: "领地")
                }

                if let best = app.royalDashboard.bestMonth {
                    Label("巅峰月份 \(monthText(best.periodStart)) · \(best.hookupCount) 次", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.gold)
                }
            }
        }
    }

    private var customization: some View {
        SectionCard("王者身份", systemImage: "person.crop.circle.badge.checkmark", tint: Palette.goldDeep) {
            VStack(spacing: 12) {
                Picker("当前封号", selection: app.royalProfileBinding(\.selectedTitleIndex)) {
                    Text("当前最高 · \(app.royalRank.title)").tag(Int?.none)
                    ForEach(0...app.royalRank.index, id: \.self) { index in
                        Text(RoyalRank.titles[index]).tag(Optional(index))
                    }
                }

                Picker("王旗", selection: app.royalProfileBinding(\.bannerStyle)) {
                    ForEach(RoyalBannerStyle.allCases) { style in
                        Label(style.label, systemImage: style.symbolName).tag(style)
                    }
                }

                Picker("王都", selection: app.royalProfileBinding(\.capitalLocationID)) {
                    Text("尚未册封").tag(String?.none)
                    ForEach(app.royalDashboard.territories) { territory in
                        Text("\(app.locationName(id: territory.locationID)) · \(territory.tier.label)")
                            .tag(Optional(territory.locationID))
                    }
                }
                .disabled(app.royalDashboard.territories.isEmpty)
            }
        }
    }

    private var entranceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            NavigationLink { LegendHallScreen() } label: {
                EntryTile(
                    title: "传奇后宫",
                    subtitle: "\(app.royalDashboard.legends.count) 张卡 · 传奇 \(legendaryCount)",
                    systemImage: "crown.fill",
                    tint: Palette.coral
                )
            }
            .buttonStyle(.plain)

            NavigationLink { TerritoryHallScreen() } label: {
                EntryTile(
                    title: "领地版图",
                    subtitle: "\(app.royalDashboard.territories.count) 处 · 王城 \(royalCityCount)",
                    systemImage: "flag.fill",
                    tint: Palette.accent
                )
            }
            .buttonStyle(.plain)

            NavigationLink { CampaignChronicleScreen() } label: {
                EntryTile(
                    title: "征服编年史",
                    subtitle: "\(app.royalDashboard.monthlyCampaigns.count) 月战报 · \(app.royalDashboard.personalRecords.count) 项纪录",
                    systemImage: "book.closed.fill",
                    tint: Palette.goldDeep
                )
            }
            .buttonStyle(.plain)

            NavigationLink { RoyalShareScreen() } label: {
                EntryTile(
                    title: "匿名战绩卡",
                    subtitle: "只晒封号和数字，不带任何人或地点",
                    systemImage: "square.and.arrow.up.fill",
                    tint: Palette.safe
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var records: some View {
        if !app.royalDashboard.personalRecords.isEmpty {
            SectionCard("王者纪录", systemImage: "trophy.fill", tint: Palette.goldDeep) {
                VStack(spacing: 0) {
                    ForEach(Array(app.royalDashboard.personalRecords.enumerated()), id: \.element.id) { index, record in
                        if index > 0 { Divider().padding(.leading, 36) }
                        HStack(spacing: 11) {
                            Image(systemName: record.metric.symbolName)
                                .foregroundStyle(Palette.goldDeep)
                                .frame(width: 24)
                            Text(record.metric.label)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(record.value)")
                                .font(.headline.monospacedDigit())
                            Text(recordDateText(record))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private var legendaryCount: Int { app.royalDashboard.legends.filter { $0.tier == .legendary }.count }
    private var royalCityCount: Int { app.royalDashboard.territories.filter { $0.tier == .royalCity }.count }
}

struct LegendHallScreen: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                HeroPanel(gradient: Palette.velvetGradient, watermark: "crown.fill") {
                    VStack(alignment: .leading, spacing: 7) {
                        HeroBadge(title: "战绩升阶", systemImage: "sparkles")
                        Text("传奇后宫")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                        Text("一次初猎，三次回头，五次王牌，十次封为传奇。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }

                if app.royalDashboard.legends.isEmpty {
                    EmptyStateView(symbol: "crown", title: "还没有传奇卡", message: "真正记下一次「上床了」，第一张初猎卡就会出现。")
                        .padding(.top, 24)
                } else {
                    ForEach(app.royalDashboard.legends) { legend in
                        if let companion = app.companion(id: legend.companionID) {
                            NavigationLink(value: companion.id) {
                                legendRow(legend, companion: companion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("传奇后宫")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legendRow(_ legend: CompanionLegend, companion: Companion) -> some View {
        HStack(spacing: 14) {
            AvatarView(companion: companion, size: 58)
                .overlay { Circle().stroke(legend.tier.tint, lineWidth: 3).padding(-4) }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    MaskedName(name: companion.displayName, revealed: app.namesRevealed, font: .headline)
                    TagLabel(title: legend.tier.label, systemImage: legend.tier.symbolName, tint: legend.tier.tint, filled: true)
                }
                Text("上床 \(legend.hookupCount) 次 · 私藏 \(legend.privatePhotoCount) 张 · 最近 \(Format.relativeDay(legend.lastHookupDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let remaining = legend.remainingToNext, let next = legend.tier.next {
                    ProgressView(value: Double(legend.hookupCount), total: Double(next.threshold))
                        .tint(legend.tier.tint)
                    Text("再 \(remaining) 次升为\(next.label)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("传奇已加冕")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.goldDeep)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(16)
        .glassCard(cornerRadius: 22, interactive: true, shadowRadius: 8)
    }
}

struct TerritoryHallScreen: View {
    @Environment(AppState.self) private var app
    @State private var showMap = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                HeroPanel(watermark: "map.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("领地版图")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                        Text("每一次当地战绩都在筑城：1 初征 · 3 据点 · 8 主场 · 15 王城。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.74))
                        HeroButton(title: "巡视地图", systemImage: "map.fill", prominent: true, cue: .cityFocus) { showMap = true }
                    }
                }

                if app.royalDashboard.territories.isEmpty {
                    EmptyStateView(symbol: "flag", title: "还没有领地", message: "带地点记下一次「上床了」，版图就会插下第一面旗。")
                        .padding(.top, 24)
                } else {
                    ForEach(app.royalDashboard.territories) { territory in
                        territoryRow(territory)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("领地版图")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMap) { MapScreen().presentationDragIndicator(.visible) }
    }

    private func territoryRow(_ territory: ConquestTerritory) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                ZStack {
                    Circle().fill(territory.tier.tint.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: territory.tier.symbolName).foregroundStyle(territory.tier.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(app.locationName(id: territory.locationID)).font(.headline)
                        if app.royalProfile.capitalLocationID == territory.locationID {
                            TagLabel(title: "王都", systemImage: "crown.fill", tint: Palette.goldDeep, filled: true)
                        }
                    }
                    Text("\(territory.tier.label) · \(territory.companionCount) 个她 · 回头客 \(territory.repeatCompanionCount)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(territory.hookupCount) 次").font(.headline.monospacedDigit())
            }
            if let remaining = territory.remainingToNext, let next = territory.tier.next {
                ProgressView(value: Double(territory.hookupCount), total: Double(next.threshold)).tint(territory.tier.tint)
                Text("再 \(remaining) 次升为\(next.label) · 单月最高 \(territory.bestMonthCount)")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("王城已筑成 · 单月最高 \(territory.bestMonthCount)")
                    .font(.caption2.weight(.bold)).foregroundStyle(Palette.goldDeep)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22, shadowRadius: 8)
    }
}

struct CampaignChronicleScreen: View {
    @Environment(AppState.self) private var app
    @State private var scope: CampaignScope = .month

    private var campaigns: [CampaignSummary] {
        scope == .month ? app.royalDashboard.monthlyCampaigns : app.royalDashboard.yearlyCampaigns
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                Picker("周期", selection: $scope) {
                    Text("月度战报").tag(CampaignScope.month)
                    Text("年度战报").tag(CampaignScope.year)
                }
                .pickerStyle(.segmented)

                if campaigns.isEmpty {
                    EmptyStateView(symbol: "book.closed", title: "编年史尚未开篇", message: "战绩会按月份和年份自动归档，不需要额外填写。")
                        .padding(.top, 28)
                } else {
                    ForEach(campaigns) { campaign in
                        campaignCard(campaign)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("征服编年史")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func campaignCard(_ campaign: CampaignSummary) -> some View {
        SectionCard(periodText(campaign), systemImage: "calendar", tint: Palette.goldDeep) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    compactMetric("\(campaign.hookupCount)", "上床")
                    compactMetric("\(campaign.companionCount)", "女人")
                    compactMetric("\(campaign.newConquestCount)", "新猎获")
                    compactMetric("\(campaign.newTerritoryCount)", "新领地")
                }
                HStack(spacing: 12) {
                    if let id = campaign.topCompanionID, let companion = app.companion(id: id) {
                        Label {
                            MaskedName(name: companion.displayName, revealed: app.namesRevealed, font: .caption.weight(.semibold))
                        } icon: { Image(systemName: "crown.fill") }
                    }
                    if let id = campaign.topLocationID {
                        Label(app.locationName(id: id), systemImage: "flag.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func compactMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum RoyalShareKind: String, CaseIterable, Identifiable {
    case lifetime
    case year
    case territory

    var id: String { rawValue }
    var label: String {
        switch self {
        case .lifetime: "生涯王者"
        case .year: "年度战报"
        case .territory: "领地版图"
        }
    }
}

private struct RoyalShareArtifact: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("astra-royal-card.png")
    }
}

struct RoyalShareScreen: View {
    @Environment(AppState.self) private var app
    @State private var kind: RoyalShareKind = .lifetime
    @State private var artifact: RoyalShareArtifact?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("卡面", selection: $kind) {
                    ForEach(RoyalShareKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                shareCard
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Palette.accent.opacity(0.20), radius: 18, y: 10)

                Label("不会包含代号、照片、地点名、日期、备注、坐标或健康信息", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let artifact {
                    ShareLink(item: artifact, preview: SharePreview("星图匿名战绩卡")) {
                        Label("分享匿名战绩卡", systemImage: "square.and.arrow.up.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
                } else {
                    ProgressView("正在生成安全预览…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(16)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("匿名战绩卡")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: kind) { render() }
    }

    private var shareCard: some View {
        RoyalShareCard(
            kind: kind,
            payload: AnonymousRoyalSharePayload(
                title: app.selectedRoyalTitle,
                level: app.royalRank.level,
                companionCount: app.conqueredCompanions.count,
                hookupCount: app.stats.totalIntimacyCount,
                repeatCount: app.stats.repeatGirlCount,
                territoryCount: app.conquestLocationCount,
                year: Calendar.current.component(.year, from: Date()),
                yearHookups: app.royalDashboard.yearlyCampaigns.first(where: {
                    Calendar.current.isDate($0.periodStart, equalTo: Date(), toGranularity: .year)
                })?.hookupCount ?? 0
            ),
            banner: app.royalProfile.bannerStyle
        )
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    @MainActor
    private func render() {
        let view = shareCard
            .frame(width: 900, height: 1125)
            .environment(app)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        artifact = renderer.uiImage?.pngData().map { RoyalShareArtifact(data: $0) }
    }
}

private struct RoyalShareCard: View {
    let kind: RoyalShareKind
    let payload: AnonymousRoyalSharePayload
    let banner: RoyalBannerStyle

    var body: some View {
        ZStack {
            banner.gradient
            abstractMap
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("ASTRA · 星图", systemImage: "sparkles")
                        .font(.headline.weight(.black))
                    Spacer()
                    Text("LV.\(payload.level)").font(.headline.monospacedDigit())
                }
                Spacer()
                Image(systemName: kind == .territory ? "map.fill" : "crown.fill")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(Palette.gold)
                Text(cardHeadline)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                Text(cardSubtitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                HStack(spacing: 10) {
                    shareMetric(payload.companionCount, "女人")
                    shareMetric(kind == .year ? payload.yearHookups : payload.hookupCount, kind == .year ? "今年" : "上床")
                    shareMetric(payload.repeatCount, "回头客")
                    shareMetric(payload.territoryCount, "领地")
                }
                Text("只展示匿名汇总 · 不含任何人物与地点信息")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .padding(42)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }

    private var cardHeadline: String {
        switch kind {
        case .lifetime: payload.title
        case .year: "\(payload.year) 年度战报"
        case .territory: "领地版图"
        }
    }

    private var cardSubtitle: String {
        switch kind {
        case .lifetime: "我的私人王者生涯"
        case .year: "今年的猎场，由数字作证"
        case .territory: "\(payload.territoryCount) 处战绩地已经点亮"
        }
    }

    private var abstractMap: some View {
        GeometryReader { proxy in
            let count = max(1, min(payload.territoryCount, 18))
            ZStack {
                Path { path in
                    var previous: CGPoint?
                    for index in 0..<count {
                        let point = abstractPoint(index, in: proxy.size)
                        if let previous { path.move(to: previous); path.addLine(to: point) }
                        previous = point
                    }
                }
                .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 3, dash: [8, 12]))

                ForEach(0..<count, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? Palette.gold : .white.opacity(0.32))
                        .frame(width: index == 0 ? 16 : 10, height: index == 0 ? 16 : 10)
                        .position(abstractPoint(index, in: proxy.size))
                }
            }
        }
    }

    private func abstractPoint(_ index: Int, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * (0.14 + 0.72 * pseudo(index, seed: 7)),
            y: size.height * (0.12 + 0.55 * pseudo(index, seed: 19))
        )
    }

    private func pseudo(_ index: Int, seed: Int) -> Double {
        Double((index * 37 + seed * 17) % 101) / 100
    }

    private func shareMetric(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)").font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
    }
}

private func monthText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy 年 M 月"
    return formatter.string(from: date)
}

private func periodText(_ campaign: CampaignSummary) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = campaign.scope == .month ? "yyyy 年 M 月" : "yyyy 年"
    return formatter.string(from: campaign.periodStart)
}

private func recordDateText(_ record: PersonalRecord) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = record.metric == .singleDay ? "yyyy/M/d" : "yyyy/M"
    return formatter.string(from: record.achievedAt)
}
