import Foundation
import SwiftUI

enum AchievementCategory: String, CaseIterable, Hashable, Sendable, Identifiable {
    case hunt
    case hookup
    case missed
    case trail
    case album
    case play

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hunt: "猎获"
        case .hookup: "上床"
        case .missed: "复盘"
        case .trail: "足迹"
        case .album: "私藏"
        case .play: "玩法"
        }
    }

    var symbolName: String {
        switch self {
        case .hunt: "person.2.fill"
        case .hookup: "flame.fill"
        case .missed: "arrow.counterclockwise.circle.fill"
        case .trail: "map.fill"
        case .album: "photo.on.rectangle.angled"
        case .play: "sparkles"
        }
    }
}

enum AchievementTier: String, CaseIterable, Hashable, Sendable {
    case bronze
    case silver
    case gold

    var label: String {
        switch self {
        case .bronze: "铜"
        case .silver: "银"
        case .gold: "金"
        }
    }

    var red: Double {
        switch self {
        case .bronze: 0.80
        case .silver: 0.70
        case .gold: 0.95
        }
    }

    var green: Double {
        switch self {
        case .bronze: 0.50
        case .silver: 0.72
        case .gold: 0.76
        }
    }

    var blue: Double {
        switch self {
        case .bronze: 0.28
        case .silver: 0.78
        case .gold: 0.22
        }
    }

    var tint: Color { Color(red: red, green: green, blue: blue) }
}

/// 根据已有档案现场计算的成就，不另存进度。
struct Achievement: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String
    var story: String
    var symbolName: String
    var category: AchievementCategory
    var tier: AchievementTier
    var red: Double
    var green: Double
    var blue: Double
    var current: Int
    var goal: Int

    var tint: Color { Color(red: red, green: green, blue: blue) }
    var isUnlocked: Bool { current >= goal }
    var remaining: Int { max(0, goal - current) }
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(current) / Double(goal))
    }

    var progressText: String {
        isUnlocked ? "已点亮" : "\(min(current, goal)) / \(goal)"
    }
}

enum AchievementCatalog {

    static let firstTierCityIDs: Set<String> = ["110000", "310000", "440100", "440300"]
    /// 这些条目可以作为已经发生的私人记录留在全册，但不进入「快要点亮」主动提示。
    private static let passiveOnlyAchievementIDs: Set<String> = [
        "bareback",
        "bareback_5",
        "creampie",
        "creampie_5",
        "outdoor_sex",
    ]

    /// 把最可能在下一次记录中点亮的目标放到前面。
    /// 已经有进度的优先，其次比较完成比例、剩余数量，最后保持目录顺序稳定。
    static func nextUp(in achievements: [Achievement], limit: Int = 3) -> [Achievement] {
        guard limit > 0 else { return [] }

        return Array(
            achievements.enumerated()
                .filter {
                    !$0.element.isUnlocked
                        && !passiveOnlyAchievementIDs.contains($0.element.id)
                }
                .sorted { lhs, rhs in
                    let left = lhs.element
                    let right = rhs.element
                    let leftStarted = left.current > 0
                    let rightStarted = right.current > 0

                    if leftStarted != rightStarted { return leftStarted && !rightStarted }
                    if left.progress != right.progress { return left.progress > right.progress }
                    if left.remaining != right.remaining { return left.remaining < right.remaining }
                    return lhs.offset < rhs.offset
                }
                .prefix(limit)
                .map(\.element)
        )
    }

    static func evaluate(companions: [Companion], encounters: [Encounter], cityCount: Int) -> [Achievement] {
        let active = companions.filter { !$0.isArchived }
        // 本地数据万一被旧版本或外部工具写出重复 ID，也不能在成就页触发运行时崩溃。
        let byID = companions.reduce(into: [UUID: Companion]()) { result, companion in
            if let current = result[companion.id], current.updatedAt > companion.updatedAt { return }
            result[companion.id] = companion
        }
        let hookups = encounters.filter(\.kind.isIntimate)
        let misses = encounters.filter(\.kind.isMissed)
        let photos = companions.flatMap(\.albumPhotoIDs)
            + encounters.flatMap(\.photoIDs)
        let weekendHookups = hookups.filter { Calendar.current.isDateInWeekend($0.date) }
        let nightHookups = hookups.filter { hour($0.date) >= 22 || hour($0.date) < 5 }
        let morningHookups = hookups.filter { let h = hour($0.date); return h >= 5 && h < 10 }
        let regulars = active.filter { $0.stage == .regular }.count
        let prospects = active.filter { $0.stage == .prospect }.count
        let casuals = active.filter { $0.stage == .casual || $0.stage == .regular }.count
        let sameDay = maxSameDay(hookups)
        let perGirl = Dictionary(grouping: hookups, by: \.companionID).mapValues(\.count)
        let maxRepeats = perGirl.values.max() ?? 0
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? .distantPast
        let monthHookups = hookups.filter { $0.date >= monthStart }.count
        let firstTier = active.contains { firstTierCityIDs.contains($0.cityID) }
            || hookups.contains { encounter in
                let cityID = encounter.cityID ?? byID[encounter.companionID]?.cityID
                return cityID.map(firstTierCityIDs.contains) ?? false
            }
        let crossCity = hookups.contains { encounter in
            guard let city = encounter.cityID, let companion = byID[encounter.companionID] else { return false }
            return city != companion.cityID
        }
        let comeback = hasComeback(in: encounters)
        let wantAgain = encounters.contains { $0.meetAgainIntent == .yes }
        let sexLogged = encounters.contains { $0.activities.contains(.vaginalPenetration) }
        let barebacks = hookups.filter { $0.protectionStatus == .noProtection }
        let creampies = hookups.filter { $0.climaxDetails.contains(.creampie) }
        let swallows = hookups.filter { $0.climaxDetails.contains(.swallow) }
        let facials = hookups.filter { $0.climaxDetails.contains(.facial) }
        let multiRounds = hookups.filter { $0.activities.contains(.multipleRounds) || $0.climaxDetails.contains(.multiple) }
        let carSex = hookups.filter { $0.activities.contains(.car) }
        let showerSex = hookups.filter { $0.activities.contains(.shower) }
        let outdoorSex = hookups.filter { $0.activities.contains(.outdoor) }
        let cowgirl = hookups.filter { $0.activities.contains(.cowgirl) }
        let sheCame = hookups.filter { $0.climaxDetails.contains(.sheCame) || $0.climaxDetails.contains(.sheMultiple) }
        let hookupCityCount = Set(hookups.compactMap { encounter in
            encounter.cityID ?? byID[encounter.companionID]?.cityID
        }).count

        return [
            make("first_girl", "猎场开门", "记下第一个她", "名册翻开第一页。", "person.fill.badge.plus", .hunt, .bronze, 0.93, 0.39, 0.60, active.count, 1),
            make("girls_3", "小有斩获", "名册里有 3 个人", "开始像那么回事了。", "person.3.fill", .hunt, .bronze, 0.93, 0.39, 0.60, active.count, 3),
            make("girls_10", "十人图鉴", "名册里有 10 个人", "一翻就是一页故事。", "square.grid.3x3.fill", .hunt, .silver, 0.94, 0.28, 0.52, active.count, 10),
            make("girls_20", "猎艳达人", "名册里有 20 个人", "这本册子已经很厚了。", "star.fill", .hunt, .gold, 0.95, 0.72, 0.22, active.count, 20),
            make("girls_40", "名册封神", "名册里有 40 个人", "猎场老人。", "crown.fill", .hunt, .gold, 0.95, 0.72, 0.22, active.count, 40),
            make("regular", "固定一位", "有人变成固定炮友", "不再是萍水相逢。", "repeat.circle.fill", .hunt, .bronze, 0.67, 0.32, 0.94, regulars, 1),
            make("regulars_3", "三位固定", "同时有 3 个固定炮友", "时间表开始要排了。", "person.3.fill", .hunt, .silver, 0.67, 0.32, 0.94, regulars, 3),
            make("prospect", "准炮友", "有人变成准炮友", "马上就要上床了。", "bolt.heart.fill", .hunt, .bronze, 0.96, 0.32, 0.42, prospects, 1),
            make("fwb", "正式炮友", "有人变成炮友", "不再只是暧昧。", "flame.fill", .hunt, .bronze, 0.94, 0.22, 0.46, casuals, 1),
            make("fwbs_3", "三个炮友", "同时有 3 个炮友或固定", "猎场开始拥挤。", "person.3.fill", .hunt, .gold, 0.94, 0.22, 0.46, casuals, 3),
            make("repeater", "回头客", "同一个人上床 3 次", "她也还想来。", "arrow.triangle.2.circlepath", .hunt, .bronze, 0.94, 0.28, 0.52, maxRepeats, 3),
            make("repeater_5", "老主顾", "同一个人上床 5 次", "熟门熟路。", "heart.circle.fill", .hunt, .silver, 0.93, 0.39, 0.60, maxRepeats, 5),

            make("first_hookup", "开张大吉", "第一次上床", "猎场正式开张。", "flame.fill", .hookup, .bronze, 0.94, 0.28, 0.52, hookups.count, 1),
            make("hookups_3", "连约三回", "累计上床 3 次", "手感回来了。", "bolt.fill", .hookup, .bronze, 0.95, 0.62, 0.25, hookups.count, 3),
            make("hookups_10", "十次打卡", "累计上床 10 次", "时间线开始有厚度。", "checkmark.seal.fill", .hookup, .silver, 0.94, 0.28, 0.52, hookups.count, 10),
            make("hookups_30", "身经百战", "累计上床 30 次", "不是碰巧，是常态。", "crown.fill", .hookup, .gold, 0.95, 0.72, 0.22, hookups.count, 30),
            make("hookups_50", "猎神", "累计上床 50 次", "这本册子可以合上再敬一杯。", "trophy.fill", .hookup, .gold, 0.95, 0.72, 0.22, hookups.count, 50),
            make("month_4", "月度丰收", "单月上床 4 次", "这个月没闲着。", "calendar.badge.plus", .hookup, .silver, 0.95, 0.62, 0.25, monthHookups, 4),
            make("double_header", "连轴转", "同一天上床两次", "日程排得够满。", "clock.badge.checkmark", .hookup, .bronze, 0.95, 0.62, 0.25, sameDay >= 2 ? 1 : 0, 1),
            make("hat_trick", "帽子戏法", "同一天上床三次", "一天三次，时间线会记得。", "flame.fill", .hookup, .gold, 0.94, 0.28, 0.52, sameDay >= 3 ? 1 : 0, 1),

            make("first_miss", "接受落空", "第一次记下没上床", "没成也算一条真实轨迹。", "xmark.circle.fill", .missed, .bronze, 0.35, 0.56, 0.94, misses.count, 1),
            make("misses_5", "五次复盘", "记下 5 次没上床", "看清哪里没成，下一次更直接。", "arrow.counterclockwise.circle.fill", .missed, .silver, 0.35, 0.56, 0.94, misses.count, 5),
            make("misses_15", "继续拓场", "记下 15 次没上床", "没困在一条路上。", "map.fill", .missed, .gold, 0.38, 0.60, 0.96, misses.count, 15),

            make("cities_3", "三城足迹", "点亮 3 座城市", "猎场开始搬家。", "mappin.and.ellipse", .trail, .bronze, 0.38, 0.60, 0.96, cityCount, 3),
            make("cities_8", "全国跑图", "点亮 8 座城市", "地图不再是空的。", "map.fill", .trail, .silver, 0.22, 0.70, 0.56, cityCount, 8),
            make("cities_15", "巡猎中国", "点亮 15 座城市", "南北都留下过。", "globe.asia.australia.fill", .trail, .gold, 0.38, 0.60, 0.96, cityCount, 15),
            make("first_tier", "一线猎场", "北上广深留下过人", "一线也不是进不去。", "building.2.fill", .trail, .silver, 0.95, 0.62, 0.25, firstTier ? 1 : 0, 1),
            make("cross_city", "跨城出击", "去她常驻城市以外上床", "车票没白买。", "airplane", .trail, .bronze, 0.38, 0.60, 0.96, crossCity ? 1 : 0, 1),

            make("first_photo", "第一张私藏", "存下第一张照片", "时间线有了插图。", "camera.fill", .album, .bronze, 0.94, 0.28, 0.52, photos.count, 1),
            make("album_10", "相册丰收", "私藏照片满 10 张", "翻起来有点危险。", "photo.on.rectangle.angled", .album, .silver, 0.88, 0.35, 0.70, photos.count, 10),
            make("album_30", "私藏满柜", "私藏照片满 30 张", "这格只能自己看。", "photo.on.rectangle.angled", .album, .gold, 0.88, 0.35, 0.70, photos.count, 30),

            make("weekend", "周末选手", "周末上床过", "周六周日有安排。", "sun.max.fill", .play, .bronze, 0.95, 0.62, 0.25, weekendHookups.count, 1),
            make("night_owl", "深夜局", "晚上 10 点后上床过", "夜才刚刚开始。", "moon.stars.fill", .play, .bronze, 0.58, 0.34, 0.92, nightHookups.count, 1),
            make("morning", "清晨局", "早上 5 到 9 点还在约", "天亮了也不急着走。", "sunrise.fill", .play, .silver, 0.95, 0.72, 0.22, morningHookups.count, 1),
            make("comeback", "后来上了", "同一个人先没上、后来上了", "一次没成不是句号。", "arrow.triangle.2.circlepath", .play, .bronze, 0.93, 0.39, 0.60, comeback ? 1 : 0, 1),
            make("want_again", "还想约", "约完还想再约", "这次不是句号。", "arrow.forward.circle.fill", .play, .bronze, 0.94, 0.28, 0.52, wantAgain ? 1 : 0, 1),
            make("sex_logged", "记到床上", "勾过做爱", "该记的都记下了。", "heart.fill", .play, .bronze, 0.94, 0.28, 0.52, sexLogged ? 1 : 0, 1),
            make("bareback", "无套", "第一次无套", "皮肤贴着皮肤。", "exclamationmark.shield.fill", .play, .bronze, 0.94, 0.42, 0.34, barebacks.count, 1),
            make("bareback_5", "无套常客", "无套 5 次", "已经不怕了。", "flame.fill", .play, .silver, 0.94, 0.22, 0.46, barebacks.count, 5),
            make("creampie", "内射", "第一次内射", "射进去了。", "drop.fill", .play, .bronze, 0.94, 0.22, 0.46, creampies.count, 1),
            make("creampie_5", "灌满", "内射 5 次", "她里面都熟了。", "drop.fill", .play, .gold, 0.94, 0.22, 0.46, creampies.count, 5),
            make("swallow", "口爆", "她咽下去过", "嘴也记下了。", "ellipsis.bubble.fill", .play, .silver, 0.93, 0.39, 0.60, swallows.count, 1),
            make("facial", "颜射", "射在脸上过", "那张脸记得很清楚。", "sparkles", .play, .silver, 0.95, 0.62, 0.25, facials.count, 1),
            make("multi_round", "多轮", "一次做了好几轮", "停不下来。", "arrow.2.squarepath", .play, .silver, 0.94, 0.28, 0.52, multiRounds.count, 1),
            make("car_sex", "车震", "在车里做过", "后座也算猎场。", "car.fill", .play, .bronze, 0.38, 0.60, 0.96, carSex.count, 1),
            make("shower_sex", "浴室", "在浴室做过", "水还没停。", "drop.fill", .play, .bronze, 0.30, 0.75, 0.60, showerSex.count, 1),
            make("outdoor_sex", "外面做", "在外面做过", "随时可能被看见。", "leaf.fill", .play, .gold, 0.22, 0.70, 0.56, outdoorSex.count, 1),
            make("cowgirl", "她骑上来", "她在上面过", "让她自己动。", "heart.circle.fill", .play, .bronze, 0.93, 0.39, 0.60, cowgirl.count, 1),
            make("she_came", "把她弄高潮", "记下过她高潮", "她也爽到了。", "waveform.path.ecg", .play, .silver, 0.94, 0.28, 0.52, sheCame.count, 1),
            make("hookup_cities_3", "三城上床", "在 3 座城市上过床", "猎场真的铺开了。", "map.fill", .play, .gold, 0.38, 0.60, 0.96, hookupCityCount, 3),
        ]
    }

    /// 同一个对象先出现「没上床」，之后又有「上床了」。
    private static func hasComeback(in encounters: [Encounter]) -> Bool {
        let grouped = Dictionary(grouping: encounters, by: \.companionID)
        return grouped.values.contains { records in
            var sawMiss = false
            for record in records.sorted(by: { $0.date < $1.date }) {
                if record.kind.isMissed { sawMiss = true }
                if sawMiss, record.kind.isIntimate { return true }
            }
            return false
        }
    }

    private static func make(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ story: String,
        _ symbol: String,
        _ category: AchievementCategory,
        _ tier: AchievementTier,
        _ r: Double,
        _ g: Double,
        _ b: Double,
        _ current: Int,
        _ goal: Int
    ) -> Achievement {
        Achievement(
            id: id,
            title: title,
            detail: detail,
            story: story,
            symbolName: symbol,
            category: category,
            tier: tier,
            red: r,
            green: g,
            blue: b,
            current: current,
            goal: goal
        )
    }

    private static func hour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private static func maxSameDay(_ hookups: [Encounter]) -> Int {
        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        var best = 0
        for encounter in hookups {
            let day = calendar.startOfDay(for: encounter.date)
            counts[day, default: 0] += 1
            best = max(best, counts[day, default: 0])
        }
        return best
    }
}
