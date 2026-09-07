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
}

extension ClimaxDetail {
    var group: ClimaxDetailGroup {
        switch self {
        case .sheCame, .sheMultiple, .sheDidNotCome, .sheNotSure: .partner
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
