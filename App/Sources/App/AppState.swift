import Foundation
import Observation
import SwiftUI

/// 地图上的一座城市 + 落在这座城市的人
struct CityBucket: Identifiable, Hashable, Sendable {
    let city: City
    let companions: [Companion]
    /// 0...1，用于气泡大小与光晕浓度
    let ratio: Double

    var id: String { city.id }
    var count: Int { companions.count }

    /// 取关系最"进"的一档作为气泡主色
    var dominantStage: RelationStage {
        companions.max { $0.stage.weight < $1.stage.weight }?.stage ?? .talking
    }
}

/// 名单页的一个分组
struct RosterSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbolName: String?
    let stage: RelationStage?
    let companions: [Companion]
}

/// 导入结果
struct ImportSummary: Sendable {
    let companionsAdded: Int
    let companionsUpdated: Int
    let encountersAdded: Int
}

@MainActor
@Observable
final class AppState {

    // MARK: - 数据

    let catalog: CityCatalog

    private(set) var companions: [Companion]
    private(set) var encounters: [Encounter]
    private(set) var settings: AppSettings
    private(set) var filter: RosterFilter

    /// 搜索词是临时状态，不落盘
    var searchText: String = ""

    /// 名字是否已揭示。开启「默认隐藏名字」后每次冷启动都重新遮住，不持久化。
    var namesRevealed: Bool = true

    // MARK: - 派生

    private(set) var buckets: [CityBucket] = []
    private(set) var stats = RosterStats()

    private let store: LocalStore

    // MARK: - 初始化

    init(store: LocalStore = .shared, catalog: CityCatalog = .shared) {
        self.store = store
        self.catalog = catalog
        self.companions = store.load([Companion].self, for: .companions, default: [])
        self.encounters = store.load([Encounter].self, for: .encounters, default: [])
        self.settings = store.load(AppSettings.self, for: .settings, default: .default)
        self.filter = store.load(RosterFilter.self, for: .filter, default: .default)
        self.namesRevealed = !self.settings.maskNamesByDefault

        Haptics.shared.configure(with: settings)
        recompute()
    }

    // MARK: - 基础查询

    var isEmpty: Bool { companions.isEmpty }

    var activeCompanions: [Companion] { companions.filter { !$0.isArchived } }

    func companion(id: UUID) -> Companion? { companions.first { $0.id == id } }

    func city(id: String) -> City? { catalog.city(id: id) }

    func city(for companion: Companion) -> City? { catalog.city(id: companion.cityID) }

    func cityName(for companion: Companion) -> String {
        catalog.city(id: companion.cityID)?.name ?? "未知城市"
    }

    /// 该人的全部记录，按时间倒序。
    /// 直接从可观察的 `encounters` 计算，保证 UI 随数据自动刷新。
    func encounters(for companionID: UUID) -> [Encounter] {
        encounters.filter { $0.companionID == companionID }
    }

    /// 最后一次互动时间；没有记录就退回「认识时间 / 建档时间」
    func lastContact(for companion: Companion) -> Date {
        encounters
            .filter { $0.companionID == companion.id }
            .map(\.date)
            .max() ?? companion.metDate ?? companion.createdAt
    }

    func daysSinceContact(for companion: Companion) -> Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: lastContact(for: companion))
        let to = calendar.startOfDay(for: Date())
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    /// 是否超过了这个人自己的提醒间隔
    func isOverdue(_ companion: Companion) -> Bool {
        guard !companion.isArchived, companion.stage.isActive,
              let interval = companion.reminderIntervalDays, interval > 0
        else { return false }
        return daysSinceContact(for: companion) >= interval
    }

    /// 首页「该联系了」清单，最久没联系的排前面
    var needsAttention: [Companion] {
        activeCompanions
            .filter { isOverdue($0) }
            .sorted { daysSinceContact(for: $0) > daysSinceContact(for: $1) }
    }

    /// 30 天内要过生日的人
    var upcomingBirthdays: [Companion] {
        activeCompanions
            .compactMap { companion -> (Companion, Int)? in
                guard let days = companion.daysUntilBirthday, days <= 30 else { return nil }
                return (companion, days)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// 全部用过的标签（含自定义），按使用频次降序
    var usedTags: [String] {
        var counts: [String: Int] = [:]
        for companion in companions {
            for tag in companion.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    // MARK: - 名单

    /// 应用筛选 + 搜索 + 排序
    func filteredCompanions() -> [Companion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let matched = companions.filter { companion in
            guard filter.matches(companion, isOverdue: isOverdue(companion)) else { return false }
            guard !query.isEmpty else { return true }
            return matchesSearch(companion, query: query)
        }

        return sort(matched, by: settings.rosterSort)
    }

    private func matchesSearch(_ companion: Companion, query: String) -> Bool {
        if companion.name.lowercased().contains(query) { return true }
        if companion.occupation.lowercased().contains(query) { return true }
        if companion.notes.lowercased().contains(query) { return true }
        if companion.contactNote.lowercased().contains(query) { return true }
        if companion.metChannel.lowercased().contains(query) { return true }
        if companion.tags.contains(where: { $0.lowercased().contains(query) }) { return true }
        if let city = catalog.city(id: companion.cityID) {
            if city.name.contains(query) { return true }
            if city.pinyin.hasPrefix(query) || city.abbr == query { return true }
            if city.province.contains(query) { return true }
        }
        return false
    }

    private func sort(_ list: [Companion], by sort: RosterSort) -> [Companion] {
        // 置顶永远在最前
        func compare(_ a: Companion, _ b: Companion) -> Bool {
            if a.isPinned != b.isPinned { return a.isPinned }
            switch sort {
            case .lastContact:
                return lastContact(for: a) > lastContact(for: b)
            case .rating:
                if a.rating != b.rating { return a.rating > b.rating }
                return lastContact(for: a) > lastContact(for: b)
            case .stage:
                if a.stage.weight != b.stage.weight { return a.stage.weight > b.stage.weight }
                return a.rating > b.rating
            case .name:
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            case .city:
                let ca = catalog.city(id: a.cityID)?.pinyin ?? "zzz"
                let cb = catalog.city(id: b.cityID)?.pinyin ?? "zzz"
                if ca != cb { return ca < cb }
                return a.rating > b.rating
            case .added:
                return a.createdAt > b.createdAt
            }
        }
        return list.sorted(by: compare)
    }

    /// 分组后的名单
    func rosterSections() -> [RosterSection] {
        let list = filteredCompanions()

        switch settings.rosterGrouping {
        case .none:
            guard !list.isEmpty else { return [] }
            return [RosterSection(id: "all", title: "全部", symbolName: nil, stage: nil, companions: list)]

        case .stage:
            return RelationStage.allCases
                .sorted { $0.weight > $1.weight }
                .compactMap { stage in
                    let members = list.filter { $0.stage == stage }
                    guard !members.isEmpty else { return nil }
                    return RosterSection(
                        id: stage.rawValue,
                        title: stage.label,
                        symbolName: stage.symbolName,
                        stage: stage,
                        companions: members
                    )
                }

        case .city:
            let grouped = Dictionary(grouping: list, by: \.cityID)
            return grouped
                .map { cityID, members -> RosterSection in
                    RosterSection(
                        id: cityID,
                        title: catalog.city(id: cityID)?.name ?? "未知城市",
                        symbolName: "mappin.circle.fill",
                        stage: nil,
                        companions: members
                    )
                }
                .sorted {
                    if $0.companions.count != $1.companions.count {
                        return $0.companions.count > $1.companions.count
                    }
                    return $0.title < $1.title
                }
        }
    }

    // MARK: - 时间线

    /// 全部记录按时间倒序，可选只看某个人
    func timeline(companionID: UUID? = nil, limit: Int? = nil) -> [Encounter] {
        var list = encounters
        if let companionID { list = list.filter { $0.companionID == companionID } }
        if let limit { return Array(list.prefix(limit)) }
        return list
    }

    /// 按「年-月」分组的时间线
    func timelineSections(companionID: UUID? = nil) -> [(title: String, encounters: [Encounter])] {
        let calendar = Calendar.current
        let formatter = DateFormatter.monthTitle
        var order: [String] = []
        var grouped: [String: [Encounter]] = [:]

        for encounter in timeline(companionID: companionID) {
            let start = calendar.dateInterval(of: .month, for: encounter.date)?.start ?? encounter.date
            let key = formatter.string(from: start)
            if grouped[key] == nil {
                grouped[key] = []
                order.append(key)
            }
            grouped[key]?.append(encounter)
        }

        return order.map { ($0, grouped[$0] ?? []) }
    }

    // MARK: - 修改：档案

    /// 生成一份带默认值的新档案
    func makeDraftCompanion(cityID: String? = nil) -> Companion {
        Companion(
            paletteIndex: (companions.count + 1) % Palette.avatarGradients.count,
            cityID: cityID ?? companions.last?.cityID ?? "310000",
            reminderIntervalDays: settings.defaultReminderDays
        )
    }

    func upsert(_ companion: Companion) {
        var updated = companion
        updated.updatedAt = Date()

        if let index = companions.firstIndex(where: { $0.id == companion.id }) {
            companions[index] = updated
            Haptics.shared.play(.success)
        } else {
            companions.append(updated)
            Haptics.shared.play(.pinDrop)
        }
        persistCompanions()
    }

    func delete(companionID: UUID) {
        companions.removeAll { $0.id == companionID }
        encounters.removeAll { $0.companionID == companionID }
        persistCompanions()
        persistEncounters()
        Haptics.shared.play(.warning)
    }

    func togglePin(_ companion: Companion) {
        guard let index = companions.firstIndex(where: { $0.id == companion.id }) else { return }
        companions[index].isPinned.toggle()
        companions[index].updatedAt = Date()
        persistCompanions()
        Haptics.shared.play(companions[index].isPinned ? .toggleOn : .toggleOff)
    }

    func toggleArchive(_ companion: Companion) {
        guard let index = companions.firstIndex(where: { $0.id == companion.id }) else { return }
        companions[index].isArchived.toggle()
        if companions[index].isArchived { companions[index].isPinned = false }
        companions[index].updatedAt = Date()
        persistCompanions()
        Haptics.shared.play(.mediumTap)
    }

    func setStage(_ stage: RelationStage, for companion: Companion) {
        guard let index = companions.firstIndex(where: { $0.id == companion.id }),
              companions[index].stage != stage
        else { return }
        companions[index].stage = stage
        companions[index].updatedAt = Date()
        persistCompanions()
        Haptics.shared.play(.cityFocus)
    }

    func setRating(_ rating: Int, for companion: Companion) {
        guard let index = companions.firstIndex(where: { $0.id == companion.id }) else { return }
        let clamped = min(max(rating, 0), 5)
        guard companions[index].rating != clamped else { return }
        companions[index].rating = clamped
        companions[index].updatedAt = Date()
        persistCompanions()
        Haptics.shared.play(.selection)
    }

    // MARK: - 修改：记录

    func upsert(_ encounter: Encounter) {
        if let index = encounters.firstIndex(where: { $0.id == encounter.id }) {
            encounters[index] = encounter
        } else {
            encounters.append(encounter)
        }
        persistEncounters()
        Haptics.shared.play(.waveSent)
    }

    func delete(encounterID: UUID) {
        encounters.removeAll { $0.id == encounterID }
        persistEncounters()
        Haptics.shared.play(.toggleOff)
    }

    /// 「刚联系过」快捷记一笔
    func logQuickContact(for companion: Companion, kind: EncounterKind = .chat) {
        upsert(Encounter(companionID: companion.id, date: Date(), kind: kind, cityID: companion.cityID))
    }

    // MARK: - 修改：设置 / 筛选

    func updateSettings(_ newValue: AppSettings) {
        let maskChanged = newValue.maskNamesByDefault != settings.maskNamesByDefault
        settings = newValue
        store.save(settings, for: .settings)
        Haptics.shared.configure(with: settings)
        if maskChanged { namesRevealed = !settings.maskNamesByDefault }
        recompute()
    }

    func toggleNamesRevealed() {
        namesRevealed.toggle()
        Haptics.shared.play(namesRevealed ? .toggleOn : .toggleOff)
    }

    func settingsBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                var copy = self.settings
                copy[keyPath: keyPath] = newValue
                self.updateSettings(copy)
            }
        )
    }

    func updateFilter(_ newValue: RosterFilter) {
        filter = newValue
        store.save(filter, for: .filter)
    }

    func mutateFilter(_ transform: (inout RosterFilter) -> Void) {
        var copy = filter
        transform(&copy)
        updateFilter(copy)
    }

    func filterBinding<T>(_ keyPath: WritableKeyPath<RosterFilter, T>) -> Binding<T> {
        Binding(
            get: { self.filter[keyPath: keyPath] },
            set: { newValue in
                var copy = self.filter
                copy[keyPath: keyPath] = newValue
                self.updateFilter(copy)
            }
        )
    }

    func resetFilter() {
        updateFilter(.default)
        Haptics.shared.play(.mediumTap)
    }

    // MARK: - 备份

    func makeBackup() throws -> Data {
        try BackupService.encode(companions: companions, encounters: encounters)
    }

    @discardableResult
    func importBackup(_ data: Data, replaceExisting: Bool) throws -> ImportSummary {
        let payload = try BackupService.decode(data)

        if replaceExisting {
            companions = payload.companions
            encounters = payload.encounters
            persistCompanions()
            persistEncounters()
            Haptics.shared.play(.success)
            return ImportSummary(
                companionsAdded: payload.companions.count,
                companionsUpdated: 0,
                encountersAdded: payload.encounters.count
            )
        }

        var added = 0
        var updated = 0
        for incoming in payload.companions {
            if let index = companions.firstIndex(where: { $0.id == incoming.id }) {
                // 以更新时间较新的一份为准
                if incoming.updatedAt > companions[index].updatedAt {
                    companions[index] = incoming
                    updated += 1
                }
            } else {
                companions.append(incoming)
                added += 1
            }
        }

        let existingEncounterIDs = Set(encounters.map(\.id))
        let newEncounters = payload.encounters.filter { !existingEncounterIDs.contains($0.id) }
        encounters.append(contentsOf: newEncounters)

        persistCompanions()
        persistEncounters()
        Haptics.shared.play(.success)

        return ImportSummary(
            companionsAdded: added,
            companionsUpdated: updated,
            encountersAdded: newEncounters.count
        )
    }

    func eraseAllLocalData() {
        store.removeAll()
        companions = []
        encounters = []
        settings = .default
        filter = .default
        searchText = ""
        Haptics.shared.configure(with: settings)
        recompute()
        Haptics.shared.play(.warning)
    }

    // MARK: - 私有

    private func persistCompanions() {
        store.save(companions, for: .companions)
        recompute()
    }

    private func persistEncounters() {
        store.save(encounters, for: .encounters)
        recompute()
    }

    private func recompute() {
        encounters.sort { $0.date > $1.date }
        rebuildBuckets()
        rebuildStats()
    }

    private func rebuildBuckets() {
        let grouped = Dictionary(grouping: activeCompanions, by: \.cityID)
        let maxCount = max(1, grouped.values.map(\.count).max() ?? 1)

        buckets = grouped.compactMap { cityID, members -> CityBucket? in
            guard let city = catalog.city(id: cityID) else { return nil }
            return CityBucket(
                city: city,
                companions: members.sorted { $0.stage.weight > $1.stage.weight },
                ratio: Double(members.count) / Double(maxCount)
            )
        }
        .sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.city.pinyin < $1.city.pinyin
        }
    }

    private func rebuildStats() {
        var result = RosterStats()
        let active = activeCompanions

        result.activeCount = active.count
        result.archivedCount = companions.count - active.count
        result.cityCount = Set(active.map(\.cityID)).count

        for companion in active {
            result.stageBreakdown[companion.stage, default: 0] += 1
        }

        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date.distantPast

        var moodTotal = 0
        var moodCount = 0
        for encounter in encounters {
            result.spendAllTime += encounter.cost ?? 0
            moodTotal += encounter.mood
            moodCount += 1
            if encounter.date >= monthStart {
                result.encountersThisMonth += 1
                if encounter.kind.isInPerson { result.meetupsThisMonth += 1 }
                result.spendThisMonth += encounter.cost ?? 0
            }
        }
        result.averageMood = moodCount > 0 ? Double(moodTotal) / Double(moodCount) : nil

        if let longest = active
            .filter({ $0.stage.isActive })
            .max(by: { daysSinceContact(for: $0) < daysSinceContact(for: $1) }) {
            result.longestSilenceName = longest.displayName
            result.longestSilenceDays = daysSinceContact(for: longest)
        }

        result.busiestCityName = buckets.first?.city.name

        stats = result
    }
}
