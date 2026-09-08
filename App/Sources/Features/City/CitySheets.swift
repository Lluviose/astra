import SwiftUI

/// 点击地图气泡后弹出的地点面板。
struct CityDetailSheet: View {

    let bucket: CityBucket
    var onAdd: (Companion) -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var stageCounts: [(RelationStage, Int)] {
        var counts: [RelationStage: Int] = [:]
        for companion in bucket.companions { counts[companion.stage, default: 0] += 1 }
        return RelationStage.allCases
            .sorted { $0.weight > $1.weight }
            .compactMap { stage in counts[stage].map { (stage, $0) } }
    }

    private var hookupCompanionIDs: Set<UUID> {
        Set(bucket.encounters.filter { $0.kind.isIntimate }.map(\.companionID))
    }

    private var hookupCompanions: [Companion] {
        bucket.companions
            .filter { hookupCompanionIDs.contains($0.id) }
            .sorted { app.hookupCount(for: $0.id) > app.hookupCount(for: $1.id) }
    }

    private var otherCompanions: [Companion] {
        bucket.companions.filter { !hookupCompanionIDs.contains($0.id) }
    }

    private var conquestRank: Int? {
        app.conquestBuckets.firstIndex { $0.id == bucket.id }.map { $0 + 1 }
    }

    private var placeWord: String { bucket.city.isCountry ? "这个国家" : "这座城" }

    /// 只用这个地点的上床记录算的小结。
    private var localInsights: EncounterInsights {
        EncounterInsights.compute(encounters: bucket.encounters, companions: bucket.companions)
    }

    private var topVenue: VenueCategory? {
        var counts: [VenueCategory: Int] = [:]
        for encounter in bucket.encounters where encounter.kind.isIntimate && encounter.venueCategory != .notRecorded {
            counts[encounter.venueCategory, default: 0] += 1
        }
        return counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key.rawValue > rhs.key.rawValue
        }?.key
    }

    private var localPhotoCount: Int {
        bucket.encounters.reduce(0) { $0 + $1.photoIDs.count }
    }

    private var recordSection: some View {
        let insights = localInsights
        return Section("\(placeWord)的战绩") {
            if let first = insights.firstHookupDate {
                LabeledContent("首战", value: DateFormatter.dayFull.string(from: first))
            }
            if let last = bucket.lastHookupDate {
                LabeledContent("最近一次", value: Format.relativeDay(last))
            }
            if let topVenue {
                LabeledContent("常去") {
                    Label(topVenue.label, systemImage: topVenue.symbolName)
                }
            }
            if let minutes = insights.averageDurationMinutes {
                LabeledContent("平均多久", value: Encounter.durationText(minutes: Int(minutes.rounded())))
            }
            if let part = insights.favoriteDayPart {
                LabeledContent("常在", value: "\(part.label) \(part.hoursLabel)")
            }
            if insights.spendRecordedCount > 0 {
                LabeledContent("花费合计", value: Format.money(insights.totalSpend))
            }
            if localPhotoCount > 0 {
                LabeledContent("留下的照片", value: "\(localPhotoCount) 张")
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if bucket.hookupCount > 0 {
                    recordSection
                }

                if !hookupCompanions.isEmpty {
                    Section("\(placeWord)拿下的") {
                        ForEach(hookupCompanions) { companion in
                            NavigationLink(value: companion.id) {
                                CompanionRow(companion: companion, showCity: false)
                            }
                        }
                    }
                }

                if !bucket.encounters.isEmpty {
                    Section("\(placeWord)的战绩时间线") {
                        ForEach(Array(bucket.encounters.prefix(12))) { encounter in
                            if app.companion(id: encounter.companionID) != nil {
                                NavigationLink(value: encounter.companionID) {
                                    EncounterRow(encounter: encounter)
                                }
                            }
                        }
                    }
                }

                if !otherCompanions.isEmpty {
                    Section("还在名册里") {
                        ForEach(otherCompanions) { companion in
                            NavigationLink(value: companion.id) {
                                CompanionRow(companion: companion, showCity: false)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(bucket.city.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                CompanionDetailView(companionID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.shared.play(.mediumTap)
                        onAdd(app.makeDraftCompanion(cityID: bucket.city.id))
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("在\(bucket.city.name)添加")
                }
            }
        }
        .presentationDetents([.height(420), .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(420)))
        .onAppear { Haptics.shared.play(.sheetRise) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let flag = bucket.city.flagEmoji {
                    Text(flag)
                        .font(.title2)
                } else {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(bucket.mapTint)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        bucket.city.isCountry
                            ? "\(bucket.city.province) · 只记到国家"
                            : "\(bucket.city.shortProvince) · \(bucket.city.tier.label)"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        bucket.hookupCount > 0
                            ? "\(bucket.hookupCompanionCount) 个她 · 上床 \(bucket.hookupCount) 次"
                            : "\(bucket.count) 个人 · 还没有战绩"
                    )
                        .font(.title3.weight(.bold))
                }

                Spacer()

                if let conquestRank {
                    Label("#\(conquestRank)", systemImage: conquestRank == 1 ? "crown.fill" : "medal.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(conquestRank == 1 ? Palette.goldDeep : Palette.coral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(bucket.mapTint.opacity(0.12), in: Capsule())
                }
            }

            if !stageCounts.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(stageCounts, id: \.0) { stage, count in
                        TagLabel(
                            title: "\(stage.label) \(count)",
                            systemImage: stage.symbolName,
                            tint: stage.tint
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Label("上床 \(bucket.hookupCount)", systemImage: "flame.fill")
                    .foregroundStyle(EncounterKind.intimacy.tint)
                Label("没上 \(bucket.missedCount)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(EncounterKind.missed.tint)
                if let rate = bucket.hookupRate {
                    Text("上床率 \(rate.formatted(.percent.precision(.fractionLength(0))))")
                        .foregroundStyle(.secondary)
                }
                if let date = bucket.lastRecordDate {
                    Spacer()
                    Text(Format.relativeDay(date))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, shadowRadius: 8)
    }
}

// MARK: - 地点选择

private enum LocationPickerScope: String, CaseIterable, Identifiable {
    case china
    case international

    var id: String { rawValue }

    var label: String {
        switch self {
        case .china: "中国城市"
        case .international: "境外国家"
        }
    }

    var helpText: String {
        switch self {
        case .china: "中国选到具体城市。"
        case .international: "境外只记到国家，不再细分省市。"
        }
    }
}

/// 中国到城市、境外到国家的选择列表。sheet 和编辑器内嵌路由共用这一份，
/// 中文 / 拼音 / 首字母 / 英文 / 国家代码都能搜。
struct LocationPickerList: View {

    /// 当前已选中的地点，用来打勾并决定默认展开哪一档。
    var selectedID: String?
    var onSelect: (City) -> Void

    @Environment(AppState.self) private var app

    @State private var query = ""
    @State private var scope: LocationPickerScope = .china

    private var searchResults: [City] { app.catalog.search(query) }

    private var selected: City? { selectedID.flatMap { app.location(id: $0) } }

    private var knownLocations: [City] {
        app.buckets.map(\.city).filter { $0.isCountry == (scope == .international) }
    }

    private var featuredTiers: [(CityTier, [City])] {
        let grouped = Dictionary(grouping: app.catalog.cities, by: \.tier)
        return [CityTier.first, .newFirst, .second].compactMap { tier in
            guard let cities = grouped[tier], !cities.isEmpty else { return nil }
            return (tier, cities.sorted { $0.pinyin < $1.pinyin })
        }
    }

    private var otherByProvince: [(String, [City])] {
        let others = app.catalog.cities.filter { $0.tier == .other }
        let grouped = Dictionary(grouping: others, by: \.shortProvince)
        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .compactMap { key in
                guard let cities = grouped[key], !cities.isEmpty else { return nil }
                return (key, cities.sorted { $0.pinyin < $1.pinyin })
            }
    }

    private var countriesByRegion: [(String, [City])] {
        let order = ["亚洲", "欧洲", "北美洲", "南美洲", "大洋洲", "非洲"]
        let grouped = Dictionary(grouping: app.catalog.countries, by: \.province)
        return order.compactMap { region in
            guard let countries = grouped[region], !countries.isEmpty else { return nil }
            return (region, countries.sorted { $0.pinyin < $1.pinyin })
        }
    }

    var body: some View {
        List {
            if !query.isEmpty {
                Section("搜索结果") {
                    ForEach(searchResults) { row($0) }
                }
            } else {
                Section {
                    Picker("地点范围", selection: $scope) {
                        ForEach(LocationPickerScope.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(scope.helpText)
                }

                if let selected {
                    Section("当前选择") { row(selected) }
                }

                if !knownLocations.isEmpty {
                    Section("已有记录") {
                        ForEach(knownLocations) { row($0) }
                    }
                }

                if scope == .china {
                    ForEach(featuredTiers, id: \.0) { tier, cities in
                        Section(tier.label) {
                            ForEach(cities) { row($0) }
                        }
                    }
                    ForEach(otherByProvince, id: \.0) { province, cities in
                        Section(province) {
                            ForEach(cities) { row($0) }
                        }
                    }
                } else {
                    ForEach(countriesByRegion, id: \.0) { region, countries in
                        Section(region) {
                            ForEach(countries) { row($0) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if !query.isEmpty, searchResults.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "国家 / 城市 / 拼音 / 首字母 / 英文"
        )
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onAppear {
            if selected?.isCountry == true { scope = .international }
        }
    }

    private func row(_ city: City) -> some View {
        Button {
            Haptics.shared.play(.cityFocus)
            onSelect(city)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).font(.body)
                    Text(city.locationSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let bucket = app.buckets.first(where: { $0.id == city.id }) {
                    Text("\(bucket.mapCount)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(bucket.mapTint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background { Capsule().fill(bucket.mapTint.opacity(0.15)) }
                }
                if city.id == selectedID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 独立弹出的地点选择面板。
struct CityPickerSheet: View {

    var title: String
    var selectedID: String? = nil
    var onSelect: (City) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LocationPickerList(selectedID: selectedID) { city in
                onSelect(city)
                dismiss()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear { Haptics.shared.play(.sheetRise) }
    }
}

/// 嵌在编辑表单导航栈里的地点选择页。
struct LocationPickerRoute: View {

    @Binding var cityID: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LocationPickerList(selectedID: cityID) { city in
            cityID = city.id
            dismiss()
        }
        .navigationTitle("选择地点")
        .navigationBarTitleDisplayMode(.inline)
    }
}
