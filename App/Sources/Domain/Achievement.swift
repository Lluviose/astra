import Foundation
import SwiftUI

/// 根据已有档案现场计算的成就，不另存进度。
struct Achievement: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String
    var symbolName: String
    var red: Double
    var green: Double
    var blue: Double
    var current: Int
    var goal: Int

    var tint: Color { Color(red: red, green: green, blue: blue) }
    var isUnlocked: Bool { current >= goal }
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(current) / Double(goal))
    }

    var progressText: String {
        isUnlocked ? "已解锁" : "\(min(current, goal)) / \(goal)"
    }
}

enum AchievementCatalog {

    static func evaluate(companions: [Companion], encounters: [Encounter], cityCount: Int) -> [Achievement] {
        let active = companions.filter { !$0.isArchived }
        let hookups = encounters.filter(\.kind.isIntimate)
        let overnight = encounters.filter { $0.kind == .overnight }
        let photos = companions.compactMap(\.photoID) + encounters.flatMap(\.photoIDs)
        let weekendHookups = hookups.filter { Calendar.current.isDateInWeekend($0.date) }
        let nightHookups = hookups.filter { hour($0.date) >= 22 || hour($0.date) < 5 }
        let hasRegular = active.contains { $0.stage == .regular }
        let sameDay = hasTwoHookupsSameDay(hookups)

        return [
            make("first_girl", "猎场开门", "记下第一个她", "person.fill.badge.plus", 0.93, 0.39, 0.60, active.count, 1),
            make("first_hookup", "开张大吉", "第一次约成", "flame.fill", 0.94, 0.28, 0.52, hookups.count, 1),
            make("first_overnight", "留宿成功", "第一次过夜", "moon.fill", 0.58, 0.34, 0.92, overnight.count, 1),
            make("hookups_3", "连约三回", "累计约成 3 次", "bolt.fill", 0.95, 0.62, 0.25, hookups.count, 3),
            make("hookups_10", "十次打卡", "累计约成 10 次", "checkmark.seal.fill", 0.94, 0.28, 0.52, hookups.count, 10),
            make("hookups_30", "身经百战", "累计约成 30 次", "crown.fill", 0.95, 0.72, 0.22, hookups.count, 30),
            make("girls_3", "小有斩获", "名册里有 3 个人", "person.3.fill", 0.93, 0.39, 0.60, active.count, 3),
            make("girls_10", "十人图鉴", "名册里有 10 个人", "square.grid.3x3.fill", 0.94, 0.28, 0.52, active.count, 10),
            make("girls_20", "猎艳达人", "名册里有 20 个人", "star.fill", 0.95, 0.72, 0.22, active.count, 20),
            make("cities_3", "三城足迹", "点亮 3 座城市", "mappin.and.ellipse", 0.38, 0.60, 0.96, cityCount, 3),
            make("cities_8", "全国跑图", "点亮 8 座城市", "map.fill", 0.22, 0.70, 0.56, cityCount, 8),
            make("first_photo", "第一张私藏", "存下第一张照片", "camera.fill", 0.94, 0.28, 0.52, photos.count, 1),
            make("album_10", "相册丰收", "私藏照片满 10 张", "photo.on.rectangle.angled", 0.88, 0.35, 0.70, photos.count, 10),
            make("weekend", "周末选手", "周末约成过", "sun.max.fill", 0.95, 0.62, 0.25, weekendHookups.count, 1),
            make("night_owl", "深夜局", "晚上 10 点后约成过", "moon.stars.fill", 0.58, 0.34, 0.92, nightHookups.count, 1),
            make("regular", "固定一位", "有人变成固定约", "repeat.circle.fill", 0.67, 0.32, 0.94, hasRegular ? 1 : 0, 1),
            make("double_header", "连轴转", "同一天约成两次", "clock.badge.checkmark", 0.95, 0.62, 0.25, sameDay ? 1 : 0, 1),
        ]
    }

    private static func make(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ symbol: String,
        _ r: Double,
        _ g: Double,
        _ b: Double,
        _ current: Int,
        _ goal: Int
    ) -> Achievement {
        Achievement(id: id, title: title, detail: detail, symbolName: symbol, red: r, green: g, blue: b, current: current, goal: goal)
    }

    private static func hour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private static func hasTwoHookupsSameDay(_ hookups: [Encounter]) -> Bool {
        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        for encounter in hookups {
            let day = calendar.startOfDay(for: encounter.date)
            counts[day, default: 0] += 1
            if counts[day]! >= 2 { return true }
        }
        return false
    }
}
