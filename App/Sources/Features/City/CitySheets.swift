import SwiftUI

/// 点击地图气泡后弹出的城市面板
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("这座城市的人") {
                    ForEach(bucket.companions) { companion in
                        NavigationLink(value: companion.id) {
                            CompanionRow(companion: companion, showCity: false)
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
                        var draft = app.makeDraftCompanion(cityID: bucket.city.id)
                        draft.cityID = bucket.city.id
                        dismiss()
                        onAdd(draft)
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
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(bucket.dominantStage.tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(bucket.city.shortProvince) · \(bucket.city.tier.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(bucket.count) 人")
                        .font(.title3.weight(.bold))
                }

                Spacer()
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
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, shadowRadius: 8)
    }
}

// MARK: - 城市选择器

/// 中国城市选择器：支持中文、全拼、首字母缩写搜索。
struct CityPickerSheet: View {

    var title: String
    var subtitle: String?
    var onSelect: (City) -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var searchResults: [City] {
        app.catalog.search(query)
    }

    private var knownCities: [City] {
        app.buckets.map(\.city)
    }

    private var allCitiesByTier: [(CityTier, [City])] {
        let grouped = Dictionary(grouping: app.catalog.cities, by: \.tier)
        return CityTier.allCases.compactMap { tier in
            guard let cities = grouped[tier], !cities.isEmpty else { return nil }
            return (tier, cities.sorted { $0.pinyin < $1.pinyin })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.isEmpty {
                    Section("搜索结果") {
                        ForEach(searchResults) { city in row(city) }
                    }
                } else {
                    if !knownCities.isEmpty {
                        Section("已有记录") {
                            ForEach(knownCities) { city in row(city) }
                        }
                    }
                    ForEach(allCitiesByTier, id: \.0) { tier, cities in
                        Section(tier.label) {
                            ForEach(cities) { city in row(city) }
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: subtitle ?? "城市 / 拼音 / 首字母，如 hz、杭州"
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear { Haptics.shared.play(.sheetRise) }
    }

    private func row(_ city: City) -> some View {
        Button {
            Haptics.shared.play(.cityFocus)
            dismiss()
            onSelect(city)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name).font(.body)
                    Text("\(city.shortProvince) · \(city.pinyin)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let bucket = app.buckets.first(where: { $0.id == city.id }) {
                    Text("\(bucket.count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(bucket.dominantStage.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background {
                            Capsule().fill(bucket.dominantStage.tint.opacity(0.15))
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
