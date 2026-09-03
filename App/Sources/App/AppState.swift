import Foundation
import Observation
import SwiftUI

/// 地图上的一个地点 + 落在这个地点的人。
/// 中国地点是城市，境外地点是国家。
struct CityBucket: Identifiable, Hashable, Sendable {
    let city: City
    let companions: [Companion]
    let encounters: [Encounter]

    var id: String { city.id }
    var count: Int { companions.count }
    var recordCount: Int { encounters.count }
    var hookupCount: Int { encounters.filter { $0.kind.isIntimate }.count }
    var missedCount: Int { encounters.filter { $0.kind.isMissed }.count }
    var hookupCompanionCount: Int {
        Set(encounters.filter { $0.kind.isIntimate }.map(\.companionID)).count
    }
    var lastHookupDate: Date? {
        encounters.first { $0.kind.isIntimate }?.date
    }
    var hookupRate: Double? {
        guard recordCount > 0 else { return nil }
        return Double(hookupCount) / Double(recordCount)
    }
    /// 没有结果记录时仍显示这座城里的人数。
    var mapCount: Int { recordCount > 0 ? recordCount : count }
    var lastRecordDate: Date? { encounters.first?.date }

    /// 取相处状态最靠前的一档作为气泡主色
    var dominantStage: RelationStage {
        companions.max { $0.stage.weight < $1.stage.weight }?.stage ?? .chatting
    }

    /// 有结果时优先按结果着色，没有结果时沿用关系阶段色。
    var mapTint: Color {
        if hookupCount > 0 { return EncounterKind.intimacy.tint }
        if missedCount > 0 { return EncounterKind.missed.tint }
        return dominantStage.tint
    }
}

/// 对象页的一个分组
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
    private(set) var royalProfile: RoyalProfile
    private(set) var seenAchievementIDs: Set<String>
    private(set) var pendingUnlocks: [Achievement] = []
    private(set) var pendingRewards: [RewardEvent] = []

    /// 搜索词是临时状态，不落盘
    var searchText: String = ""
    /// RootView 的结算浮层借此请求首页打开王者殿堂。
    var royalHallRequestToken: Int = 0

    /// 代号是否已揭示。开启「默认隐藏代号」后每次冷启动都重新遮住，不持久化。
    var namesRevealed: Bool = true

    // MARK: - 派生

    private(set) var buckets: [CityBucket] = []
    private(set) var stats = IntimacyStats()
    /// 全部记录的战绩统计，随数据变化重算。
    private(set) var insights = EncounterInsights()
    private(set) var royalDashboard = RoyalDashboard(
        legends: [], territories: [], monthlyCampaigns: [], yearlyCampaigns: [], personalRecords: []
    )

    private let store: LocalStore
    private var isBooting = true

    // MARK: - 初始化

    init(
        store: LocalStore = .shared,
        catalog: CityCatalog = .shared,
        performsMediaMaintenance: Bool = true
    ) {
        let storedCompanions = store.loadIfPresent([Companion].self, for: .companions)
        let storedEncounters = store.loadIfPresent([Encounter].self, for: .encounters)
        self.store = store
        self.catalog = catalog
        self.companions = storedCompanions ?? []
        self.encounters = storedEncounters ?? []
        self.settings = store.load(AppSettings.self, for: .settings, default: .default)
        self.filter = store.load(RosterFilter.self, for: .filter, default: .default)
        self.royalProfile = store.load(RoyalProfile.self, for: .royalProfile, default: .default)
        self.seenAchievementIDs = store.load(Set<String>.self, for: .seenAchievements, default: [])
        self.namesRevealed = !self.settings.maskNamesByDefault

        Haptics.shared.configure(with: settings)
        MediaStore.enableSystemBackup()
        // 只有两份引用元数据都成功解码时才做回收；任一文件损坏都宁可保留照片，
        // 不能把临时回退到空数组当成“用户确实删除了全部档案”。
        if performsMediaMaintenance, storedCompanions != nil, storedEncounters != nil {
            MediaStore.gc(referenced: Self.referencedIDs(companions: self.companions, encounters: self.encounters))
        }
        recompute()
        normalizeRoyalProfile()
        seedSeenAchievementsIfNeeded()
        isBooting = false
    }

    // MARK: - 基础查询

    var isEmpty: Bool { companions.isEmpty }

    /// 当前仍在相处的对象；暂停、结束或已归档的不计入首页统计和快捷记录。
    var currentCompanions: [Companion] {
        companions.filter { !$0.isArchived && $0.stage.isActive }
    }

    /// 真正记录过「上床了」的人才进入后宫图鉴；结束或归档后仍保留在私人收藏里。
    var conqueredCompanions: [Companion] {
        let grouped = Dictionary(
            grouping: encounters.filter { $0.kind.isIntimate },
            by: \.companionID
        )
        return companions
            .filter { grouped[$0.id]?.isEmpty == false }
            .sorted { lhs, rhs in
                let left = grouped[lhs.id] ?? []
                let right = grouped[rhs.id] ?? []
                if left.count != right.count { return left.count > right.count }
                let leftDate = left.map(\.date).max() ?? .distantPast
                let rightDate = right.map(\.date).max() ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return lhs.overallScore > rhs.overallScore
            }
    }

    /// 只统计后宫图鉴里的艳照与单次战果照片，不把头像、人物照和档案照片混进来。
    var privateCollectionCount: Int {
        var ids = Set<String>()
        for companion in conqueredCompanions {
            ids.formUnion(albumIDs(for: companion.id))
        }
        return ids.count
    }

    /// 按上床次数排列的战绩地点。
    var conquestBuckets: [CityBucket] {
        buckets
            .filter { $0.hookupCount > 0 }
            .sorted { lhs, rhs in
                if lhs.hookupCount != rhs.hookupCount { return lhs.hookupCount > rhs.hookupCount }
                if lhs.hookupCompanionCount != rhs.hookupCompanionCount {
                    return lhs.hookupCompanionCount > rhs.hookupCompanionCount
                }
                return (lhs.lastHookupDate ?? .distantPast) > (rhs.lastHookupDate ?? .distantPast)
            }
    }

    var conquestLocationCount: Int { conquestBuckets.count }

    var topConquestBucket: CityBucket? { conquestBuckets.first }

    func companion(id: UUID) -> Companion? { companions.first { $0.id == id } }

    func location(id: String) -> City? { catalog.location(id: id) }

    func location(for companion: Companion) -> City? { catalog.location(id: companion.cityID) }

    func locationName(for companion: Companion) -> String {
        catalog.location(id: companion.cityID)?.name ?? "未知地点"
    }

    func locationName(id: String) -> String {
        catalog.location(id: id)?.name ?? "未知地点"
    }

    /// 记录自己填的地点优先，没填就沿用她的常驻地。
    func locationName(for encounter: Encounter) -> String {
        if let id = encounter.cityID, let location = catalog.location(id: id) { return location.name }
        return companion(id: encounter.companionID).map { locationName(for: $0) } ?? "未知地点"
    }

    var hasCountryLocations: Bool { buckets.contains { $0.city.isCountry } }

    /// 该人的全部记录，按时间倒序。
    /// 直接从可观察的 `encounters` 计算，保证 UI 随数据自动刷新。
    func encounters(for companionID: UUID) -> [Encounter] {
        encounters
            .filter { $0.companionID == companionID }
            .sorted { $0.date > $1.date }
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

    /// 首页联系周期清单，最久没联系的排前面
    var needsAttention: [Companion] {
        currentCompanions
            .filter { isOverdue($0) }
            .sorted { daysSinceContact(for: $0) > daysSinceContact(for: $1) }
    }

    /// 用户明确标记、尚未完成的事后任务。有日期的优先，并按最近到期排序。
    var pendingFollowUps: [Encounter] {
        encounters
            .filter(\.hasPendingFollowUp)
            .sorted { lhs, rhs in
                switch (lhs.followUpDate, rhs.followUpDate) {
                case let (left?, right?):
                    if left != right { return left < right }
                    return lhs.date > rhs.date
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.date > rhs.date
                }
            }
    }

    /// 30 天内要过生日的人
    var upcomingBirthdays: [Companion] {
        currentCompanions
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

    var referencedMediaIDs: Set<String> {
        Self.referencedIDs(companions: companions, encounters: encounters)
    }

    var achievements: [Achievement] {
        AchievementCatalog.evaluate(
            companions: companions,
            encounters: encounters,
            cityCount: buckets.count
        )
    }

    var royalRank: RoyalRank { RoyalRank.resolve(from: achievements) }

    var selectedRoyalTitle: String {
        let rank = royalRank
        let selected = royalProfile.selectedTitleIndex.map { min(max($0, 0), rank.index) } ?? rank.index
        return RoyalRank.titles[selected]
    }

    var capitalTerritory: ConquestTerritory? {
        guard let id = royalProfile.capitalLocationID else { return nil }
        return royalDashboard.territories.first { $0.locationID == id }
    }

    func updateRoyalProfile(_ newValue: RoyalProfile) {
        royalProfile = newValue
        normalizeRoyalProfile()
        store.save(royalProfile, for: .royalProfile)
        Haptics.shared.play(.toggleOn)
    }

    func royalProfileBinding<T>(_ keyPath: WritableKeyPath<RoyalProfile, T>) -> Binding<T> {
        Binding(
            get: { self.royalProfile[keyPath: keyPath] },
            set: { value in
                var copy = self.royalProfile
                copy[keyPath: keyPath] = value
                self.updateRoyalProfile(copy)
            }
        )
    }

    func dismissRewards() {
        pendingRewards = []
    }

    func requestRoyalHall() {
        royalHallRequestToken &+= 1
    }

    /// 某个人的战绩小结。
    func companionInsights(for companionID: UUID) -> EncounterInsights {
        EncounterInsights.compute(
            encounters: encounters(for: companionID),
            companions: companion(id: companionID).map { [$0] } ?? []
        )
    }

    var unlockedAchievementCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var unseenUnlockCount: Int {
        achievements.filter { $0.isUnlocked && !seenAchievementIDs.contains($0.id) }.count
    }

    func isUnseen(_ achievement: Achievement) -> Bool {
        achievement.isUnlocked && !seenAchievementIDs.contains(achievement.id)
    }

    func dismissUnlocks() {
        seenAchievementIDs.formUnion(pendingUnlocks.map(\.id))
        pendingUnlocks = []
        persistSeenAchievements()
    }

    func markAllUnlockedSeen() {
        seenAchievementIDs.formUnion(achievements.filter(\.isUnlocked).map(\.id))
        pendingUnlocks = []
        persistSeenAchievements()
    }

    func albumIDs(for companionID: UUID) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        func append(_ id: String) {
            if seen.insert(id).inserted { ids.append(id) }
        }
        guard let companion = companion(id: companionID) else { return [] }
        companion.albumPhotoIDs.forEach(append)
        for encounter in encounters(for: companionID) {
            encounter.photoIDs.forEach(append)
        }
        return ids
    }

    func profilePhotoIDs(for companionID: UUID) -> [String] {
        guard let companion = companion(id: companionID) else { return [] }
        var seen = Set<String>()
        return ([companion.photoID].compactMap { $0 } + companion.profilePhotoIDs).filter {
            seen.insert($0).inserted
        }
    }

    func dossierPhotoIDs(for companionID: UUID) -> [String] {
        guard let companion = companion(id: companionID) else { return [] }
        var seen = Set<String>()
        return companion.dossierPhotoIDs.filter { seen.insert($0).inserted }
    }

    /// 产品约束：人物照、档案照片和艳照不设置应用层数量上限。
    func addProfilePhotoIDs(_ ids: [String], to companionID: UUID) {
        guard let index = companions.firstIndex(where: { $0.id == companionID }) else {
            deleteUnreferencedMedia(Set(ids))
            return
        }
        var seen = Set(companions[index].profilePhotoIDs)
        let added = ids.filter { MediaStore.isValidID($0) && seen.insert($0).inserted }
        guard !added.isEmpty else {
            deleteUnreferencedMedia(Set(ids))
            return
        }
        companions[index].profilePhotoIDs.append(contentsOf: added)
        companions[index].updatedAt = Date()
        persistCompanions()
        deleteUnreferencedMedia(Set(ids).subtracting(added))
        Haptics.shared.play(.toggleOn)
    }

    func addDossierPhotoIDs(_ ids: [String], to companionID: UUID) {
        guard let index = companions.firstIndex(where: { $0.id == companionID }) else {
            deleteUnreferencedMedia(Set(ids))
            return
        }
        var seen = Set(companions[index].dossierPhotoIDs)
        let added = ids.filter { MediaStore.isValidID($0) && seen.insert($0).inserted }
        guard !added.isEmpty else {
            deleteUnreferencedMedia(Set(ids))
            return
        }
        companions[index].dossierPhotoIDs.append(contentsOf: added)
        companions[index].updatedAt = Date()
        persistCompanions()
        deleteUnreferencedMedia(Set(ids).subtracting(added))
        Haptics.shared.play(.toggleOn)
    }

    func addAlbumPhotoIDs(_ ids: [String], to companionID: UUID) {
        guard let index = companions.firstIndex(where: { $0.id == companionID }) else {
            deleteUnreferencedMedia(Set(ids))
            return
        }
        var seen = Set(companions[index].albumPhotoIDs)
        let added = ids.filter { MediaStore.isValidID($0) && seen.insert($0).inserted }
        guard !added.isEmpty else {
            deleteUnreferencedMedia(Set(ids))
            return
        }
        companions[index].albumPhotoIDs.append(contentsOf: added)
        companions[index].updatedAt = Date()
        persistCompanions()
        deleteUnreferencedMedia(Set(ids).subtracting(added))
        Haptics.shared.play(.toggleOn)
    }

    func removeAlbumPhoto(_ id: String, from companionID: UUID) {
        var companionChanged = false
        var encountersChanged = false
        if let index = companions.firstIndex(where: { $0.id == companionID }) {
            if companions[index].albumPhotoIDs.contains(id) {
                companions[index].albumPhotoIDs.removeAll { $0 == id }
                companionChanged = true
            }
            if companionChanged {
                companions[index].updatedAt = Date()
            }
        }
        for index in encounters.indices
            where encounters[index].companionID == companionID && encounters[index].photoIDs.contains(id) {
            encounters[index].photoIDs.removeAll { $0 == id }
            encountersChanged = true
        }
        guard companionChanged || encountersChanged else { return }
        if companionChanged { persistCompanions() }
        if encountersChanged { persistEncounters() }
        deleteUnreferencedMedia(Set([id]))
        Haptics.shared.play(.toggleOff)
    }

    func removeProfilePhoto(_ id: String, from companionID: UUID) {
        guard let index = companions.firstIndex(where: { $0.id == companionID }) else { return }
        var changed = false
        if companions[index].photoID == id {
            companions[index].photoID = nil
            changed = true
        }
        if companions[index].profilePhotoIDs.contains(id) {
            companions[index].profilePhotoIDs.removeAll { $0 == id }
            changed = true
        }
        guard changed else { return }
        companions[index].updatedAt = Date()
        persistCompanions()
        deleteUnreferencedMedia(Set([id]))
        Haptics.shared.play(.toggleOff)
    }

    func removeDossierPhoto(_ id: String, from companionID: UUID) {
        guard let index = companions.firstIndex(where: { $0.id == companionID }),
              companions[index].dossierPhotoIDs.contains(id)
        else { return }
        companions[index].dossierPhotoIDs.removeAll { $0 == id }
        companions[index].updatedAt = Date()
        persistCompanions()
        deleteUnreferencedMedia(Set([id]))
        Haptics.shared.play(.toggleOff)
    }

    func hookupCount(for companionID: UUID) -> Int {
        encounters.filter { $0.companionID == companionID && $0.kind.isIntimate }.count
    }

    func missedCount(for companionID: UUID) -> Int {
        encounters.filter { $0.companionID == companionID && $0.kind.isMissed }.count
    }

    func lastHookup(for companionID: UUID) -> Encounter? {
        encounters
            .filter { $0.companionID == companionID && $0.kind.isIntimate }
            .max { $0.date < $1.date }
    }

    /// 依照真实战果时间串起地点；连续发生在同一地点时只保留一个节点。
    func conquestLocationPath() -> [City] {
        let companionsByID = companions.reduce(into: [UUID: Companion]()) { result, companion in
            result[companion.id] = companion
        }
        let orderedCities = encounters
            .filter { $0.kind.isIntimate }
            .sorted { $0.date < $1.date }
            .compactMap { encounter -> City? in
                let cityID = encounter.cityID ?? companionsByID[encounter.companionID]?.cityID
                return cityID.flatMap { catalog.location(id: $0) }
            }

        var path: [City] = []
        for city in orderedCities where path.last?.id != city.id {
            path.append(city)
        }
        return path
    }

    // MARK: - 对象

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
        if companion.expectations.lowercased().contains(query) { return true }
        if companion.boundaries.lowercased().contains(query) { return true }
        if companion.safetyNotes.lowercased().contains(query) { return true }
        if companion.bustSizeText?.lowercased().contains(query) == true { return true }
        if companion.tags.contains(where: { $0.lowercased().contains(query) }) { return true }
        if let city = catalog.location(id: companion.cityID) {
            if city.name.contains(query) { return true }
            let aliases = (city.pinyin + " " + city.abbr).split(separator: " ").map(String.init)
            if aliases.contains(where: { $0.hasPrefix(query) }) { return true }
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
                if a.overallScore != b.overallScore { return a.overallScore > b.overallScore }
                return lastContact(for: a) > lastContact(for: b)
            case .stage:
                if a.stage.weight != b.stage.weight { return a.stage.weight > b.stage.weight }
                return a.overallScore > b.overallScore
            case .name:
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            case .city:
                let ca = catalog.location(id: a.cityID)?.pinyin ?? "zzz"
                let cb = catalog.location(id: b.cityID)?.pinyin ?? "zzz"
                if ca != cb { return ca < cb }
                return a.overallScore > b.overallScore
            case .added:
                return a.createdAt > b.createdAt
            case .hookups:
                let ha = hookupCount(for: a.id)
                let hb = hookupCount(for: b.id)
                if ha != hb { return ha > hb }
                return lastContact(for: a) > lastContact(for: b)
            }
        }
        return list.sorted(by: compare)
    }

    /// 分组后的对象列表
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
                        title: catalog.location(id: cityID)?.name ?? "未知地点",
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
        if let limit { return Array(list.prefix(max(0, limit))) }
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
            rating: 0,
            scorecard: .empty
        )
    }

    func upsert(_ companion: Companion) {
        var updated = companion
        var mediaCandidates = Set<String>()
        updated.rating = updated.scorecard.legacyStarRating
        updated.updatedAt = Date()

        if let index = companions.firstIndex(where: { $0.id == companion.id }) {
            if companions[index].photoID != updated.photoID, let old = companions[index].photoID {
                mediaCandidates.insert(old)
            }
            let removedProfile = Set(companions[index].profilePhotoIDs).subtracting(updated.profilePhotoIDs)
            let removedDossier = Set(companions[index].dossierPhotoIDs).subtracting(updated.dossierPhotoIDs)
            let removedAlbum = Set(companions[index].albumPhotoIDs).subtracting(updated.albumPhotoIDs)
            mediaCandidates.formUnion(removedProfile)
            mediaCandidates.formUnion(removedDossier)
            mediaCandidates.formUnion(removedAlbum)
            companions[index] = updated
            Haptics.shared.play(.success)
        } else {
            companions.append(updated)
            Haptics.shared.play(.pinDrop)
        }
        persistCompanions()
        deleteUnreferencedMedia(mediaCandidates)
    }

    func delete(companionID: UUID) {
        var mediaCandidates = Set<String>()
        if let companion = companion(id: companionID) {
            if let photoID = companion.photoID {
                mediaCandidates.insert(photoID)
            }
            mediaCandidates.formUnion(companion.profilePhotoIDs)
            mediaCandidates.formUnion(companion.dossierPhotoIDs)
            mediaCandidates.formUnion(companion.albumPhotoIDs)
        }
        let photos = encounters.filter { $0.companionID == companionID }.flatMap(\.photoIDs)
        mediaCandidates.formUnion(photos)
        companions.removeAll { $0.id == companionID }
        encounters.removeAll { $0.companionID == companionID }
        persistCompanions()
        persistEncounters()
        deleteUnreferencedMedia(mediaCandidates)
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
        let migratedScorecard = CompanionScorecard.balanced(fromLegacyRating: clamped)
        guard companions[index].rating != clamped || companions[index].scorecard != migratedScorecard else { return }
        companions[index].rating = clamped
        companions[index].scorecard = migratedScorecard
        companions[index].updatedAt = Date()
        persistCompanions()
    }

    // MARK: - 修改：记录

    func upsert(_ encounter: Encounter) {
        let previousSnapshot = RoyalConquestEngine.snapshot(royalDashboard)
        var normalized = encounter
        normalized.normalizeForOutcome()
        var mediaCandidates = Set<String>()
        if let index = encounters.firstIndex(where: { $0.id == normalized.id }) {
            let removed = Set(encounters[index].photoIDs).subtracting(normalized.photoIDs)
            mediaCandidates.formUnion(removed)
            encounters[index] = normalized
        } else {
            encounters.append(normalized)
        }
        persistEncounters()
        captureRoyalRewards(from: previousSnapshot)
        deleteUnreferencedMedia(mediaCandidates)
        Haptics.shared.play(.waveSent)
    }

    func delete(encounterID: UUID) {
        var mediaCandidates = Set<String>()
        if let encounter = encounters.first(where: { $0.id == encounterID }) {
            mediaCandidates.formUnion(encounter.photoIDs)
        }
        encounters.removeAll { $0.id == encounterID }
        persistEncounters()
        deleteUnreferencedMedia(mediaCandidates)
        Haptics.shared.play(.toggleOff)
    }

    /// 快捷记下这次有没有上床。
    func logQuickOutcome(for companion: Companion, kind: EncounterKind = .missed) {
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
        try BackupService.encode(
            companions: companions,
            encounters: encounters,
            royalProfile: royalProfile,
            media: MediaStore.collect(ids: Array(referencedMediaIDs))
        )
    }

    @discardableResult
    func importBackup(_ data: Data, replaceExisting: Bool) throws -> ImportSummary {
        let payload = try BackupService.decode(data)

        if replaceExisting {
            let referenced = Self.referencedIDs(
                companions: payload.companions,
                encounters: payload.encounters
            )
            let media = payload.media.filter { referenced.contains($0.key) }
            guard MediaStore.restore(media).isEmpty else {
                throw BackupError.cannotRestoreMedia
            }

            // 新照片全部写入成功后再切换元数据，最后才清理旧文件；导入失败时原档案仍可用。
            companions = payload.companions
            encounters = payload.encounters
            royalProfile = payload.royalProfile
            persistCompanions()
            persistEncounters()
            normalizeRoyalProfile()
            store.save(royalProfile, for: .royalProfile)
            MediaStore.gc(referenced: referenced)
            Haptics.shared.play(.success)
            return ImportSummary(
                companionsAdded: payload.companions.count,
                companionsUpdated: 0,
                encountersAdded: payload.encounters.count
            )
        }

        var added = 0
        var updated = 0
        var mergedCompanions = companions
        for incoming in payload.companions {
            if let index = mergedCompanions.firstIndex(where: { $0.id == incoming.id }) {
                // 以更新时间较新的一份为准
                if incoming.updatedAt > mergedCompanions[index].updatedAt {
                    mergedCompanions[index] = incoming
                    updated += 1
                }
            } else {
                mergedCompanions.append(incoming)
                added += 1
            }
        }

        let existingEncounterIDs = Set(encounters.map(\.id))
        let newEncounters = payload.encounters.filter { !existingEncounterIDs.contains($0.id) }
        let mergedEncounters = encounters + newEncounters
        let referenced = Self.referencedIDs(
            companions: mergedCompanions,
            encounters: mergedEncounters
        )
        let media = payload.media.filter { referenced.contains($0.key) }
        guard MediaStore.restore(media, overwriteExisting: false).isEmpty else {
            throw BackupError.cannotRestoreMedia
        }

        companions = mergedCompanions
        encounters = mergedEncounters
        if royalProfile == .default, payload.royalProfile != .default {
            royalProfile = payload.royalProfile
            normalizeRoyalProfile()
            store.save(royalProfile, for: .royalProfile)
        }
        persistCompanions()
        persistEncounters()
        MediaStore.gc(referenced: referenced)
        Haptics.shared.play(.success)

        return ImportSummary(
            companionsAdded: added,
            companionsUpdated: updated,
            encountersAdded: newEncounters.count
        )
    }

    func eraseAllLocalData() {
        store.removeAll()
        MediaStore.deleteAll()
        companions = []
        encounters = []
        settings = .default
        filter = .default
        royalProfile = .default
        seenAchievementIDs = []
        pendingUnlocks = []
        pendingRewards = []
        searchText = ""
        namesRevealed = !settings.maskNamesByDefault
        Haptics.shared.configure(with: settings)
        recompute()
        Haptics.shared.play(.warning)
    }

    // MARK: - 私有

    private func persistSeenAchievements() {
        store.save(seenAchievementIDs, for: .seenAchievements)
    }

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
        insights = EncounterInsights.compute(encounters: encounters, companions: companions)
        royalDashboard = RoyalConquestEngine.build(
            companions: companions,
            encounters: encounters,
            albumCount: { [self] in albumIDs(for: $0).count }
        )
        normalizeRoyalProfile()
        if !isBooting {
            captureUnlocks()
        }
    }

    private func seedSeenAchievementsIfNeeded() {
        let unlockedIDs = Set(achievements.filter(\.isUnlocked).map(\.id))
        guard seenAchievementIDs.isEmpty, !unlockedIDs.isEmpty else { return }
        seenAchievementIDs = unlockedIDs
        persistSeenAchievements()
    }

    private func normalizeRoyalProfile() {
        if let selected = royalProfile.selectedTitleIndex {
            royalProfile.selectedTitleIndex = min(max(selected, 0), royalRank.index)
        }
        if let capital = royalProfile.capitalLocationID,
           !royalDashboard.territories.contains(where: { $0.locationID == capital }) {
            royalProfile.capitalLocationID = nil
        }
    }

    private func captureRoyalRewards(from previous: RoyalSnapshot) {
        let current = RoyalConquestEngine.snapshot(royalDashboard)
        var events: [RewardEvent] = []

        for legend in royalDashboard.legends {
            let old = previous.legendTiers[legend.companionID] ?? .none
            guard legend.tier.rawValue > old.rawValue else { continue }
            let name = namesRevealed ? companion(id: legend.companionID)?.displayName ?? "她" : "一位她"
            events.append(RewardEvent(
                kind: .legendUpgrade,
                title: "\(name) · \(legend.tier.label)",
                detail: "传奇后宫卡已经升阶",
                symbolName: legend.tier.symbolName,
                tint: legend.tier == .legendary ? .gold : .coral
            ))
        }

        for territory in royalDashboard.territories {
            let old = previous.territoryTiers[territory.locationID] ?? .none
            guard territory.tier.rawValue > old.rawValue else { continue }
            events.append(RewardEvent(
                kind: .territoryUpgrade,
                title: "\(locationName(id: territory.locationID)) · \(territory.tier.label)",
                detail: "领地已经升阶",
                symbolName: territory.tier.symbolName,
                tint: territory.tier == .royalCity ? .gold : .accent
            ))
        }

        for record in royalDashboard.personalRecords {
            let old = previous.records[record.metric] ?? 0
            guard record.value > old else { continue }
            events.append(RewardEvent(
                kind: .personalRecord,
                title: "刷新纪录 · \(record.metric.label)",
                detail: "新纪录 \(record.value)",
                symbolName: record.metric.symbolName,
                tint: .gold
            ))
        }

        pendingRewards = Array(events.prefix(5))
    }

    private func captureUnlocks() {
        let fresh = achievements.filter { $0.isUnlocked && !seenAchievementIDs.contains($0.id) }
        let freshIDs = Set(fresh.map(\.id))
        let pendingIDs = Set(pendingUnlocks.map(\.id))
        guard freshIDs != pendingIDs else { return }
        pendingUnlocks = fresh
    }

    private func rebuildBuckets() {
        let residentsByCity = Dictionary(grouping: currentCompanions, by: \.cityID)
        let companionsByID = companions.reduce(into: [UUID: Companion]()) { result, companion in
            result[companion.id] = companion
        }
        var recordsByCity: [String: [Encounter]] = [:]
        for encounter in encounters {
            guard let cityID = encounter.cityID ?? companionsByID[encounter.companionID]?.cityID else { continue }
            recordsByCity[cityID, default: []].append(encounter)
        }

        let cityIDs = Set(residentsByCity.keys).union(Set(recordsByCity.keys))
        buckets = cityIDs.compactMap { cityID -> CityBucket? in
            guard let city = catalog.location(id: cityID) else { return nil }
            let cityRecords = (recordsByCity[cityID] ?? []).sorted { $0.date > $1.date }
            var membersByID: [UUID: Companion] = [:]
            for companion in residentsByCity[cityID] ?? [] {
                membersByID[companion.id] = companion
            }
            for record in cityRecords {
                if let companion = companionsByID[record.companionID] {
                    membersByID[companion.id] = companion
                }
            }
            let members = membersByID.values.sorted { lhs, rhs in
                if lhs.stage.weight != rhs.stage.weight { return lhs.stage.weight > rhs.stage.weight }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            return CityBucket(
                city: city,
                companions: members,
                encounters: cityRecords
            )
        }
        .sorted {
            if $0.mapCount != $1.mapCount { return $0.mapCount > $1.mapCount }
            return $0.city.pinyin < $1.city.pinyin
        }
    }

    private func rebuildStats() {
        var result = IntimacyStats()
        let current = currentCompanions

        result.activeCount = current.count
        result.cityCount = buckets.count
        result.photoCount = referencedMediaIDs.count

        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date.distantPast

        for encounter in encounters {
            if encounter.kind.isIntimate {
                result.totalIntimacyCount += 1
                if encounter.date >= monthStart {
                    result.intimaciesThisMonth += 1
                    if encounter.protectionStatus.isRecorded {
                        result.safetyRecordedThisMonth += 1
                    }
                    if encounter.protectionStatus.hasBarrierGap {
                        result.unprotectedThisMonth += 1
                    }
                }
            } else if encounter.kind.isMissed {
                result.missedCount += 1
                if encounter.date >= monthStart {
                    result.missedThisMonth += 1
                }
            }
        }
        result.pendingFollowUpCount = pendingFollowUps.count

        result.girlsThisMonth = current.filter { $0.createdAt >= monthStart }.count
        result.photosThisMonth = encounters
            .filter { $0.date >= monthStart }
            .reduce(0) { $0 + $1.photoIDs.count }

        var hookupsByGirl: [UUID: Int] = [:]
        for encounter in encounters where encounter.kind.isIntimate {
            hookupsByGirl[encounter.companionID, default: 0] += 1
        }
        result.repeatGirlCount = hookupsByGirl.values.filter { $0 >= 3 }.count

        stats = result
    }

    private static func referencedIDs(companions: [Companion], encounters: [Encounter]) -> Set<String> {
        var ids = Set(companions.compactMap(\.photoID))
        for companion in companions {
            ids.formUnion(companion.profilePhotoIDs)
            ids.formUnion(companion.dossierPhotoIDs)
            ids.formUnion(companion.albumPhotoIDs)
        }
        for encounter in encounters {
            ids.formUnion(encounter.photoIDs)
        }
        return ids
    }

    static func unreferencedMediaIDs(
        among candidates: Set<String>,
        companions: [Companion],
        encounters: [Encounter]
    ) -> Set<String> {
        candidates.subtracting(referencedIDs(companions: companions, encounters: encounters))
    }

    private func deleteUnreferencedMedia(_ candidates: Set<String>) {
        guard !candidates.isEmpty else { return }
        let safeToDelete = Self.unreferencedMediaIDs(
            among: candidates,
            companions: companions,
            encounters: encounters
        )
        MediaStore.delete(ids: Array(safeToDelete))
    }
}
