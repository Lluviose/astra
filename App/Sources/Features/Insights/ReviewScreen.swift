import SwiftUI

struct ReviewScreen: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var period: RecordPeriod = .month
    @State private var showsMap = false
    @State private var editing: Encounter?

    private var records: [Encounter] { app.encounters.filter { period.contains($0.date) } }
    private var insights: EncounterInsights {
        EncounterInsights.compute(encounters: records, companions: app.companions)
    }
    private var places: [City] {
        let ids = Set(records.compactMap { $0.cityID ?? app.companion(id: $0.companionID)?.cityID })
        return ids.compactMap { app.location(id: $0) }.sorted { $0.name < $1.name }
    }
    private var days: Int { Set(records.map { Calendar.current.startOfDay(for: $0.date) }).count }
    private var photoCount: Int { Set(app.companions.flatMap { app.albumIDs(for: $0.id) }).count }

    var body: some View {
        ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    PageMasthead(eyebrow: "REFLECTIONS", title: "慢慢回看", subtitle: "让散落的片刻，在时间里连起来。")
                    Picker("回顾时间", selection: $period) {
                        ForEach(RecordPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("review-period")

                    if records.isEmpty {
                        EmptyStateView(symbol: "calendar", title: "这段时间还没有记录",
                                       message: "换一个时间范围，或写下新的片刻。",
                                       actionTitle: period == .all ? nil : "查看全部时间",
                                       action: period == .all ? nil : { period = .all })
                            .astraSurface()
                    } else {
                        overview
                        SectionCard("相处的节奏", systemImage: "chart.bar.xaxis") {
                            OutcomeMonthChart(points: EncounterInsights.monthSeries(encounters: records, monthCount: period == .year ? 12 : 6))
                                .accessibilityLabel("所选时间范围内每月的记录数量")
                        }
                        if let record = records.first(where: { !$0.note.isEmpty }) { memory(record) }
                    }

                    VStack(spacing: 0) {
                        NavigationLink { PhotoCollectionScreen(collectionOnly: false) } label: {
                            collectionLink(title: "照片", detail: "全部时间 · \(photoCount) 张", symbol: "photo.on.rectangle")
                        }
                        .accessibilityIdentifier("review-photos")
                        Divider().padding(.leading, 64)
                        Button { showsMap = true } label: {
                            collectionLink(title: "足迹地图", detail: "全部时间 · \(app.buckets.count) 个地点", symbol: "map")
                        }
                        .accessibilityIdentifier("review-map")
                    }
                    .buttonStyle(.plain).astraSurface()

                    if !places.isEmpty {
                        SectionCard("这段时间的地点", systemImage: "mappin") {
                            FlowLayout(spacing: 10, lineSpacing: 10) {
                                ForEach(places) { place in
                                    TagLabel(title: place.name, systemImage: place.isCountry ? "globe" : "mappin", tint: Palette.accent)
                                }
                            }
                        }
                    }
                    if insights.hookupCount > 0 {
                        SectionCard("保护情况", systemImage: "checkmark.shield", tint: Palette.safe) {
                            LabeledContent("已记录", value: "\(insights.protectionRecordedCount) / \(insights.hookupCount) 篇")
                            LabeledContent("全程保护", value: "\(insights.protectionCounts[.protected] ?? 0) 篇")
                            if insights.barrierGapCount > 0 {
                                LabeledContent("未全程保护", value: "\(insights.barrierGapCount) 篇")
                                    .foregroundStyle(Palette.warning)
                            }
                        }
                        .font(.subheadline)
                    }
                    Label("统计来自你主动留下的记录", systemImage: "lock")
                        .font(.caption).foregroundStyle(Palette.secondaryInk)
                        .frame(maxWidth: .infinity).padding(.bottom, 12)
                }
                .padding(AstraLayout.gutter).astraContentMargins()
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("战绩分析").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SettingsButton() }
                ToolbarItem(placement: .topBarTrailing) { PrivacyButton() }
            }
            .navigationDestination(for: UUID.self) { CompanionDetailView(companionID: $0) }
        .sheet(isPresented: $showsMap) { MapScreen() }
        .sheet(item: $editing) { EncounterEditor(encounter: $0) }
    }

    private var overview: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return layout {
            QuietMetric(value: "\(records.count)", label: "相处记录")
            QuietMetric(value: "\(days)", label: "有记录的日子")
            QuietMetric(value: "\(places.count)", label: "地点")
        }
        .padding(24).astraSurface()
    }

    private func memory(_ record: Encounter) -> some View {
        Button { editing = record } label: {
            VStack(alignment: .leading, spacing: 18) {
                Label("翻到一个片刻", systemImage: "bookmark")
                    .font(.caption).foregroundStyle(Palette.gold)
                Text(record.note)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.white).lineLimit(4)
                    .multilineTextAlignment(.leading)
                HStack {
                    if let person = app.companion(id: record.companionID) {
                        MaskedName(name: person.displayName, revealed: app.namesRevealed, font: .caption)
                    }
                    Text(Format.relativeDay(record.date)).font(.caption)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Palette.midnight, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(HapticButtonStyle())
    }

    private func collectionLink(title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Palette.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.secondaryInk)
            }
            Spacer()
            ChevronHint()
        }
        .padding(20).frame(minHeight: 80).contentShape(Rectangle())
    }
}
