import SwiftUI

/// A place is an index into memories, without territory levels or rankings.
struct CityDetailSheet: View {
    let bucket: CityBucket
    var onAdd: (Companion) -> Void
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Encounter?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bucket.city.name).font(.system(.title, design: .serif))
                        Text("\(bucket.recordCount) 篇记录 · \(bucket.count) 位人物")
                            .font(.subheadline).foregroundStyle(Palette.secondaryInk)
                    }
                    .padding(.vertical, 12).listRowBackground(Color.clear)
                }
                if !bucket.encounters.isEmpty {
                    Section("在这里的片刻") {
                        ForEach(bucket.encounters) { record in
                            Button { editing = record } label: { EncounterRow(encounter: record) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                if !bucket.companions.isEmpty {
                    Section("相关人物") {
                        ForEach(bucket.companions) { person in
                            NavigationLink(value: person.id) { CompanionRow(companion: person, showCity: false) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped).astraListStyle()
            .navigationTitle("地点记录").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { CompanionDetailView(companionID: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAdd(app.makeDraftCompanion(cityID: bucket.city.id))
                        dismiss()
                    } label: { Image(systemName: "person.badge.plus") }
                    .accessibilityLabel("在这个地点新建人物")
                }
            }
        }
        .sheet(item: $editing) { EncounterEditor(encounter: $0) }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
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
        .astraListStyle()
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
