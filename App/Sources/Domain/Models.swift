import Foundation
import SwiftUI

// MARK: - 关系阶段

enum RelationStage: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case watching   // 观察中
    case talking    // 暧昧中
    case dating     // 约会中
    case steady     // 稳定
    case cooling    // 冷却中
    case ended      // 已结束

    var id: String { rawValue }

    var label: String {
        switch self {
        case .watching: "观察中"
        case .talking: "暧昧中"
        case .dating: "约会中"
        case .steady: "稳定"
        case .cooling: "冷却中"
        case .ended: "已结束"
        }
    }

    var symbolName: String {
        switch self {
        case .watching: "eye"
        case .talking: "bubble.left.and.bubble.right.fill"
        case .dating: "heart.fill"
        case .steady: "heart.circle.fill"
        case .cooling: "snowflake"
        case .ended: "archivebox"
        }
    }

    var tint: Color {
        switch self {
        case .watching: Color(red: 0.55, green: 0.60, blue: 0.72)
        case .talking: Color(red: 0.98, green: 0.66, blue: 0.28)
        case .dating: Color(red: 0.98, green: 0.33, blue: 0.45)
        case .steady: Color(red: 0.85, green: 0.28, blue: 0.62)
        case .cooling: Color(red: 0.40, green: 0.68, blue: 0.92)
        case .ended: Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    /// 排序权重：越"进行中"越靠前
    var weight: Int {
        switch self {
        case .steady: 5
        case .dating: 4
        case .talking: 3
        case .watching: 2
        case .cooling: 1
        case .ended: 0
        }
    }

    /// 是否算作"还在进行中"
    var isActive: Bool { self != .ended }
}

// MARK: - 档案

struct Companion: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// 可选 emoji 头像；为空时用名字首字
    var emoji: String
    var paletteIndex: Int
    /// 所在城市（中国城市库的 id）
    var cityID: String
    var stage: RelationStage
    /// 0...5
    var rating: Int
    var age: Int?
    var heightCM: Int?
    /// 生日只存月/日，不强制要年份
    var birthdayMonth: Int?
    var birthdayDay: Int?
    var occupation: String
    /// 怎么认识的
    var metChannel: String
    var metDate: Date?
    /// 联系方式备注（微信号 / 备注名之类），纯文本，不联网
    var contactNote: String
    var tags: [String]
    var notes: String
    var isPinned: Bool
    var isArchived: Bool
    /// 超过这个天数没联系就在"该联系了"里提醒；nil = 不提醒
    var reminderIntervalDays: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        emoji: String = "",
        paletteIndex: Int = 0,
        cityID: String = "310000",
        stage: RelationStage = .talking,
        rating: Int = 3,
        age: Int? = nil,
        heightCM: Int? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil,
        occupation: String = "",
        metChannel: String = "",
        metDate: Date? = nil,
        contactNote: String = "",
        tags: [String] = [],
        notes: String = "",
        isPinned: Bool = false,
        isArchived: Bool = false,
        reminderIntervalDays: Int? = 14,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.paletteIndex = paletteIndex
        self.cityID = cityID
        self.stage = stage
        self.rating = rating
        self.age = age
        self.heightCM = heightCM
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.occupation = occupation
        self.metChannel = metChannel
        self.metDate = metDate
        self.contactNote = contactNote
        self.tags = tags
        self.notes = notes
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.reminderIntervalDays = reminderIntervalDays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 手写解码：老备份缺字段也能导入，不会整份失败
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        paletteIndex = try c.decodeIfPresent(Int.self, forKey: .paletteIndex) ?? 0
        cityID = try c.decodeIfPresent(String.self, forKey: .cityID) ?? "310000"
        stage = RelationStage(rawValue: try c.decodeIfPresent(String.self, forKey: .stage) ?? "") ?? .talking
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 3
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        heightCM = try c.decodeIfPresent(Int.self, forKey: .heightCM)
        birthdayMonth = try c.decodeIfPresent(Int.self, forKey: .birthdayMonth)
        birthdayDay = try c.decodeIfPresent(Int.self, forKey: .birthdayDay)
        occupation = try c.decodeIfPresent(String.self, forKey: .occupation) ?? ""
        metChannel = try c.decodeIfPresent(String.self, forKey: .metChannel) ?? ""
        metDate = try c.decodeIfPresent(Date.self, forKey: .metDate)
        contactNote = try c.decodeIfPresent(String.self, forKey: .contactNote) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        reminderIntervalDays = try c.decodeIfPresent(Int.self, forKey: .reminderIntervalDays)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    // MARK: 派生

    var displayName: String { name.isEmpty ? "未命名" : name }

    var initial: String {
        emoji.isEmpty ? String(displayName.prefix(1)) : emoji
    }

    var birthdayText: String? {
        guard let birthdayMonth, let birthdayDay else { return nil }
        return "\(birthdayMonth) 月 \(birthdayDay) 日"
    }

    /// 距离下一个生日还有几天
    var daysUntilBirthday: Int? {
        guard let month = birthdayMonth, let day = birthdayDay else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = DateComponents()
        components.month = month
        components.day = day
        guard let next = calendar.nextDate(
            after: today.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) else { return nil }
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day
    }

    var isBirthdayApproaching: Bool {
        guard let days = daysUntilBirthday else { return false }
        return days <= 14
    }
}

// MARK: - 相处记录

enum EncounterKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case meet     // 见面
    case meal     // 吃饭
    case outing   // 出去玩
    case trip     // 旅行
    case call     // 通话
    case chat     // 聊天
    case gift     // 送礼
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .meet: "见面"
        case .meal: "吃饭"
        case .outing: "出去玩"
        case .trip: "旅行"
        case .call: "通话"
        case .chat: "聊天"
        case .gift: "送礼"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .meet: "person.2.fill"
        case .meal: "fork.knife"
        case .outing: "figure.walk.motion"
        case .trip: "airplane"
        case .call: "phone.fill"
        case .chat: "message.fill"
        case .gift: "gift.fill"
        case .other: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .meet: Color(red: 0.98, green: 0.40, blue: 0.48)
        case .meal: Color(red: 0.97, green: 0.63, blue: 0.24)
        case .outing: Color(red: 0.30, green: 0.75, blue: 0.60)
        case .trip: Color(red: 0.38, green: 0.60, blue: 0.96)
        case .call: Color(red: 0.55, green: 0.48, blue: 0.92)
        case .chat: Color(red: 0.45, green: 0.72, blue: 0.90)
        case .gift: Color(red: 0.88, green: 0.35, blue: 0.70)
        case .other: Color.secondary
        }
    }

    /// 是否算「线下见面」，用于统计
    var isInPerson: Bool {
        switch self {
        case .meet, .meal, .outing, .trip: true
        case .call, .chat, .gift, .other: false
        }
    }
}

struct Encounter: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var companionID: UUID
    var date: Date
    var kind: EncounterKind
    /// 发生在哪座城市；nil 表示沿用对方常驻城市
    var cityID: String?
    var place: String
    /// 花费（元），nil 表示没记
    var cost: Double?
    /// 这次的感受 1...5
    var mood: Int
    var note: String

    init(
        id: UUID = UUID(),
        companionID: UUID,
        date: Date = Date(),
        kind: EncounterKind = .meet,
        cityID: String? = nil,
        place: String = "",
        cost: Double? = nil,
        mood: Int = 4,
        note: String = ""
    ) {
        self.id = id
        self.companionID = companionID
        self.date = date
        self.kind = kind
        self.cityID = cityID
        self.place = place
        self.cost = cost
        self.mood = mood
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        companionID = try c.decode(UUID.self, forKey: .companionID)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        kind = EncounterKind(rawValue: try c.decodeIfPresent(String.self, forKey: .kind) ?? "") ?? .meet
        cityID = try c.decodeIfPresent(String.self, forKey: .cityID)
        place = try c.decodeIfPresent(String.self, forKey: .place) ?? ""
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        mood = try c.decodeIfPresent(Int.self, forKey: .mood) ?? 4
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

// MARK: - 标签建议

enum TagSuggestions {
    static let common = [
        "温柔", "高冷", "独立", "情绪稳定", "会照顾人", "有主见", "爱笑",
        "事业型", "学生", "同行", "异地", "同城",
        "会做饭", "爱旅行", "健身", "文艺", "夜猫子", "早睡",
        "养猫", "养狗", "能喝", "不喝酒", "声音好听", "会打扮",
    ]
}
