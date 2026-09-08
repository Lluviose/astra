import Foundation

/// 场所类型独立于城市和自由备注，旧记录不猜测分类。
enum VenueCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case notRecorded, hotel, myHome, herHome, sharedHome, car, outdoors
    case restaurant, cafe, bar, entertainment, online, other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .notRecorded: "未记录"
        case .hotel: "酒店 / 民宿"
        case .myHome: "我家"
        case .herHome: "她家"
        case .sharedHome: "共同住处"
        case .car: "车里"
        case .outdoors: "户外"
        case .restaurant: "餐厅"
        case .cafe: "咖啡馆"
        case .bar: "酒吧 / 夜店"
        case .entertainment: "影院 / 娱乐场所"
        case .online: "线上，没见面"
        case .other: "其他场所"
        }
    }

    var symbolName: String {
        switch self {
        case .notRecorded: "minus.circle"
        case .hotel: "bed.double.fill"
        case .myHome: "house.fill"
        case .herHome: "house.and.flag.fill"
        case .sharedHome: "house.lodge.fill"
        case .car: "car.fill"
        case .outdoors: "leaf.fill"
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .bar: "wineglass.fill"
        case .entertainment: "popcorn.fill"
        case .online: "iphone"
        case .other: "mappin"
        }
    }

    /// 芯片上用的短名。
    var shortLabel: String {
        switch self {
        case .hotel: "酒店"
        case .bar: "酒吧"
        case .entertainment: "影院 / 娱乐"
        case .online: "线上"
        case .other: "其他"
        default: label
        }
    }

    /// 芯片按从近到远排列，未记录不单独占位。
    static var choices: [VenueCategory] {
        allCases.filter { $0 != .notRecorded }
    }
}

enum MissedProgress: String, Codable, CaseIterable, Identifiable, Sendable {
    case notRecorded, chatting, planned, cancelled, noShow, met, kissed, stayed

    var id: String { rawValue }
    var label: String {
        switch self {
        case .notRecorded: "未记录"
        case .chatting: "只聊天，还没约时间"
        case .planned: "约了时间，还没见"
        case .cancelled: "见面前取消"
        case .noShow: "约好了，没来"
        case .met: "见了面，没上床"
        case .kissed: "接吻 / 拥抱，没上床"
        case .stayed: "一起过夜，没上床"
        }
    }
}

enum MissedReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case schedule, distance, noPlace, sheDeclined, iDeclined, bothDeclined
    case noChemistry, notReady, unwell, tired, protection, boundaries, noReply, other

    var id: String { rawValue }
    var label: String {
        switch self {
        case .schedule: "时间没对上"
        case .distance: "太远 / 交通不便"
        case .noPlace: "没合适地点"
        case .sheDeclined: "她不想"
        case .iDeclined: "我不想"
        case .bothDeclined: "双方只想见面"
        case .noChemistry: "见面没感觉"
        case .notReady: "想再熟一点"
        case .unwell: "身体不舒服"
        case .tired: "太累 / 状态不好"
        case .protection: "防护没准备好"
        case .boundaries: "边界没谈拢"
        case .noReply: "没回复 / 断联"
        case .other: "其他原因"
        }
    }
}

struct RecordOptionGroup: Identifiable {
    let title: String
    let options: [String]
    var id: String { title }
}

enum ProfileSuggestions {
    static let channels = [
        RecordOptionGroup(title: "线上认识", options: ["探探", "陌陌", "Soul", "积目", "Tinder", "Bumble", "微信", "小红书", "其他 App"]),
        RecordOptionGroup(title: "线下认识", options: ["朋友介绍", "聚会", "酒吧 / 夜店", "同事", "同学", "健身 / 运动", "旅行", "搭讪"]),
    ]
    static let expectations = ["只约一次", "偶尔约", "固定炮友", "先见面再说", "先聊天", "认真恋爱", "不确定"]
    static let boundaries = ["全程戴套", "不拍照 / 录像", "不发私密图", "不留宿", "不去家里", "不喝酒", "不公开关系", "随时可以停"]
    /// 她在床上喜欢什么，方便下次照着来。
    static let turnOns = [
        "喜欢慢一点", "喜欢猛一点", "喜欢被亲脖子", "耳朵敏感", "胸敏感", "喜欢先口",
        "喜欢后入", "喜欢在上面", "喜欢被压着", "喜欢关灯", "喜欢开灯", "喜欢说骚话",
        "喜欢被夸", "喜欢被主导", "喜欢主导", "喜欢多前戏", "喜欢事后抱着", "喜欢洗完再做",
    ]
    /// 怎么约她最顺，见面前扫一眼。
    static let approach = [
        "直接约就行", "先聊两天再约", "周末才有空", "工作日晚上方便", "只能白天", "喝点酒放得开",
        "别催她", "她喜欢我主动", "她会主动约", "提前一天说", "临时也能约", "得先吃饭",
        "接她比较稳", "她愿意来我家", "只去酒店", "回复慢，别多想",
    ]
}

enum ClimaxDetailGroup: String, CaseIterable, Identifiable {
    case partner, finish, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .partner: "她有没有高潮"
        case .finish: "我有没有射、射在哪"
        case .other: "次数与其他"
        }
    }

    var details: [ClimaxDetail] {
        ClimaxDetail.allCases.filter { $0.group == self }
    }
}

/// 结果页的快捷时间：刚从酒店出来、第二天早上补记，都不该去转轮子。
enum QuickDateChoice: String, CaseIterable, Identifiable {
    case now, lastNight, thisMorning, yesterday, dayBefore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .now: "刚刚"
        case .lastNight: "昨晚"
        case .thisMorning: "今早"
        case .yesterday: "昨天下午"
        case .dayBefore: "前天晚上"
        }
    }

    func date(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        func at(_ dayOffset: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        switch self {
        case .now: return now
        case .lastNight: return at(-1, hour: 23)
        case .thisMorning: return min(at(0, hour: 8), now)
        case .yesterday: return at(-1, hour: 15)
        case .dayBefore: return at(-2, hour: 22)
        }
    }

    /// 已选时间落在哪个快捷档；不落在任何档就返回 nil，芯片全部不亮。
    static func matching(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> QuickDateChoice? {
        allCases.first { choice in
            if choice == .now { return abs(date.timeIntervalSince(now)) < 60 }
            return abs(date.timeIntervalSince(choice.date(now: now, calendar: calendar))) < 60
        }
    }
}

extension ClimaxDetail {
    var group: ClimaxDetailGroup {
        switch self {
        case .sheCame, .sheMultiple, .sheSquirted, .sheDidNotCome, .sheNotSure: .partner
        case .multiple, .edging: .other
        default: .finish
        }
    }
}

extension Encounter {
    var missedSummary: String {
        guard kind.isMissed else { return "" }
        var parts = missedProgress == .notRecorded ? [] : [missedProgress.label]
        parts += MissedReason.allCases.filter { missedReasons.contains($0) }.map(\.label)
        return parts.joined(separator: "、")
    }

    /// 只复用明确列出的字段；这次的防护、花费、地点和跟进必须独立记录。
    mutating func reuseDetails(from previous: Encounter) {
        guard kind.isIntimate, previous.kind.isIntimate else { return }
        activities = previous.activities
        climaxDetails = previous.climaxDetails
    }

    mutating func toggleClimax(_ detail: ClimaxDetail) {
        if climaxDetails.remove(detail) != nil { return }
        let unknownOrNone: Set<ClimaxDetail> = [.sheDidNotCome, .sheNotSure]
        if unknownOrNone.contains(detail) {
            climaxDetails.subtract(unknownOrNone.union([.sheCame, .sheMultiple]))
        } else if detail == .sheCame || detail == .sheMultiple {
            climaxDetails.subtract(unknownOrNone)
        }
        let finishes: Set<ClimaxDetail> = [.creampie, .pullOut, .condomFinish, .swallow, .facial, .onChest, .onBody, .multiple]
        if detail == .didNotFinish { climaxDetails.subtract(finishes) }
        if finishes.contains(detail) { climaxDetails.remove(.didNotFinish) }
        climaxDetails.insert(detail)
    }
}
