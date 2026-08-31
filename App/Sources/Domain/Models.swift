import Foundation
import SwiftUI

// MARK: - 相处状态

enum RelationStage: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case new        // 新认识
    case chatting   // 在聊天
    case flirting   // 暧昧 / 调情
    case casual     // 偶尔见面
    case regular    // 固定见面
    case paused     // 暂停联系
    case ended      // 已结束

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: "刚认识"
        case .chatting: "聊上了"
        case .flirting: "暧昧中"
        case .casual: "偶尔约"
        case .regular: "固定约"
        case .paused: "先搁着"
        case .ended: "结束了"
        }
    }

    var symbolName: String {
        switch self {
        case .new: "sparkles"
        case .chatting: "bubble.left.and.bubble.right.fill"
        case .flirting: "heart.text.square.fill"
        case .casual: "moon.stars.fill"
        case .regular: "repeat.circle.fill"
        case .paused: "pause.circle.fill"
        case .ended: "archivebox"
        }
    }

    var tint: Color {
        switch self {
        case .new: Color(red: 0.52, green: 0.58, blue: 0.72)
        case .chatting: Color(red: 0.95, green: 0.56, blue: 0.30)
        case .flirting: Color(red: 0.93, green: 0.39, blue: 0.60)
        case .casual: Color(red: 0.94, green: 0.30, blue: 0.50)
        case .regular: Color(red: 0.67, green: 0.32, blue: 0.94)
        case .paused: Color(red: 0.36, green: 0.62, blue: 0.86)
        case .ended: Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    /// 排序权重：越接近稳定相处越靠前
    var weight: Int {
        switch self {
        case .regular: 6
        case .casual: 5
        case .flirting: 4
        case .chatting: 3
        case .new: 2
        case .paused: 1
        case .ended: 0
        }
    }

    /// 是否算作当前仍在相处；暂停与结束都不触发联系提醒。
    var isActive: Bool { self != .paused && self != .ended }
}

// MARK: - 档案

struct Companion: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// 可选 emoji 头像；为空时用代号首字
    var emoji: String
    var paletteIndex: Int
    /// 所在城市（中国城市库的 id）
    var cityID: String
    var stage: RelationStage
    /// 0...5
    var rating: Int
    /// 头像照片，存在本机沙盒
    var photoID: String?
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
    /// 双方对这段关系的期待，例如只约、固定见面或保持开放。
    var expectations: String
    /// 已沟通的边界、禁区和需要再次确认的事项。
    var boundaries: String
    /// 由本人选择记录的检测、防护或其他安全备忘。
    var safetyNotes: String
    var tags: [String]
    var notes: String
    var isPinned: Bool
    var isArchived: Bool
    /// 超过这个天数没联系就在周期提示里出现；nil = 不提示
    var reminderIntervalDays: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        emoji: String = "",
        paletteIndex: Int = 0,
        cityID: String = "310000",
        stage: RelationStage = .chatting,
        rating: Int = 3,
        photoID: String? = nil,
        age: Int? = nil,
        heightCM: Int? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil,
        occupation: String = "",
        metChannel: String = "",
        metDate: Date? = nil,
        contactNote: String = "",
        expectations: String = "",
        boundaries: String = "",
        safetyNotes: String = "",
        tags: [String] = [],
        notes: String = "",
        isPinned: Bool = false,
        isArchived: Bool = false,
        reminderIntervalDays: Int? = nil,
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
        self.photoID = photoID
        self.age = age
        self.heightCM = heightCM
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.occupation = occupation
        self.metChannel = metChannel
        self.metDate = metDate
        self.contactNote = contactNote
        self.expectations = expectations
        self.boundaries = boundaries
        self.safetyNotes = safetyNotes
        self.tags = tags
        self.notes = notes
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.reminderIntervalDays = reminderIntervalDays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 容错解码：单个可选字段缺失时不让整份本地数据失效。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        paletteIndex = try c.decodeIfPresent(Int.self, forKey: .paletteIndex) ?? 0
        cityID = try c.decodeIfPresent(String.self, forKey: .cityID) ?? "310000"
        stage = RelationStage(rawValue: try c.decodeIfPresent(String.self, forKey: .stage) ?? "") ?? .chatting
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 3
        photoID = try c.decodeIfPresent(String.self, forKey: .photoID)
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        heightCM = try c.decodeIfPresent(Int.self, forKey: .heightCM)
        birthdayMonth = try c.decodeIfPresent(Int.self, forKey: .birthdayMonth)
        birthdayDay = try c.decodeIfPresent(Int.self, forKey: .birthdayDay)
        occupation = try c.decodeIfPresent(String.self, forKey: .occupation) ?? ""
        metChannel = try c.decodeIfPresent(String.self, forKey: .metChannel) ?? ""
        metDate = try c.decodeIfPresent(Date.self, forKey: .metDate)
        contactNote = try c.decodeIfPresent(String.self, forKey: .contactNote) ?? ""
        expectations = try c.decodeIfPresent(String.self, forKey: .expectations) ?? ""
        boundaries = try c.decodeIfPresent(String.self, forKey: .boundaries) ?? ""
        safetyNotes = try c.decodeIfPresent(String.self, forKey: .safetyNotes) ?? ""
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

// MARK: - 互动记录

enum EncounterKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case intimacy // 亲密见面
    case overnight // 过夜
    case meet     // 见面
    case meal     // 吃饭
    case outing   // 出去玩
    case trip     // 旅行
    case flirting // 暧昧 / 调情聊天
    case call     // 通话
    case chat     // 聊天
    case gift     // 送礼
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .intimacy: "约成了"
        case .overnight: "过夜"
        case .meet: "见面"
        case .meal: "吃饭"
        case .outing: "出去玩"
        case .trip: "一起旅行"
        case .flirting: "聊骚"
        case .call: "通话"
        case .chat: "聊天"
        case .gift: "送礼"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .intimacy: "flame.fill"
        case .overnight: "moon.fill"
        case .meet: "person.2.fill"
        case .meal: "fork.knife"
        case .outing: "figure.walk.motion"
        case .trip: "airplane"
        case .flirting: "heart.text.square.fill"
        case .call: "phone.fill"
        case .chat: "message.fill"
        case .gift: "gift.fill"
        case .other: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .intimacy: Color(red: 0.94, green: 0.28, blue: 0.52)
        case .overnight: Color(red: 0.58, green: 0.34, blue: 0.92)
        case .meet: Color(red: 0.98, green: 0.40, blue: 0.48)
        case .meal: Color(red: 0.97, green: 0.63, blue: 0.24)
        case .outing: Color(red: 0.30, green: 0.75, blue: 0.60)
        case .trip: Color(red: 0.38, green: 0.60, blue: 0.96)
        case .flirting: Color(red: 0.93, green: 0.39, blue: 0.60)
        case .call: Color(red: 0.55, green: 0.48, blue: 0.92)
        case .chat: Color(red: 0.45, green: 0.72, blue: 0.90)
        case .gift: Color(red: 0.88, green: 0.35, blue: 0.70)
        case .other: Color.secondary
        }
    }

    /// 是否算「线下见面」，用于统计
    var isInPerson: Bool {
        switch self {
        case .intimacy, .overnight, .meet, .meal, .outing, .trip: true
        case .flirting, .call, .chat, .gift, .other: false
        }
    }

    /// 是否属于需要展示防护记录的亲密事件。
    var isIntimate: Bool {
        self == .intimacy || self == .overnight
    }

    /// 是否需要展示聊天进展与线上边界。
    var isConversation: Bool {
        self == .flirting || self == .chat || self == .call
    }
}

// MARK: - 暧昧 / 调情聊天记录

enum ChatProgress: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case notRecorded
    case gettingToKnow
    case flirting
    case expectationsClear
    case discussingMeet
    case meetScheduled
    case slowingDown
    case stopped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notRecorded: "未记录"
        case .gettingToKnow: "还在摸底"
        case .flirting: "已经聊骚了"
        case .expectationsClear: "想约的事聊清了"
        case .discussingMeet: "在约见面"
        case .meetScheduled: "约好了"
        case .slowingDown: "先缓一缓"
        case .stopped: "不推进了"
        }
    }
}

/// 对方针对露骨文字、图片或视频的明确回应；不同媒介需要分别确认。
enum ExplicitContentComfort: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case notRecorded
    case explicitlyOkay
    case limited
    case wantsSlower
    case declined

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notRecorded: "未记录"
        case .explicitlyOkay: "她说可以"
        case .limited: "有范围"
        case .wantsSlower: "想慢一点"
        case .declined: "她说不行"
        }
    }

    var shouldNotEscalate: Bool {
        self == .notRecorded || self == .wantsSlower || self == .declined
    }
}

enum ExplicitMedium: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case text
    case intimateImages
    case videoCall

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: "黄段子 / 露骨文字"
        case .intimateImages: "私密照片 / 视频"
        case .videoCall: "视频开黄腔"
        }
    }
}

enum ConversationTopic: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case relationshipExpectation
    case chatPace
    case preferences
    case boundaries
    case imagePrivacy
    case protectionAndTesting
    case contraceptionPlan
    case substanceBoundary
    case meetingPlan
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relationshipExpectation: "关系期待"
        case .chatPace: "聊天尺度 / 节奏"
        case .preferences: "亲密偏好"
        case .boundaries: "边界 / 禁区"
        case .imagePrivacy: "照片与隐私"
        case .protectionAndTesting: "防护 / 检测"
        case .contraceptionPlan: "避孕方式 / 责任"
        case .substanceBoundary: "饮酒 / 物质边界"
        case .meetingPlan: "见面安排"
        case .other: "其他"
        }
    }
}

enum DigitalBoundary: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case noScreenshots
    case noForwarding
    case noSaving
    case textOnly
    case noFaceOrIdentity
    case deleteOnRequest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noScreenshots: "不截屏 / 录屏"
        case .noForwarding: "不转发"
        case .noSaving: "不保存"
        case .textOnly: "只聊文字"
        case .noFaceOrIdentity: "不带脸 / 身份信息"
        case .deleteOnRequest: "提出后删除"
        }
    }
}

/// 仅记录聊天中可观察到的账号 / 数字安全事实，不形成对人的风险评分。
enum ConversationSafetyFlag: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case identityNotConfirmed
    case moneyRequest
    case suspiciousLink
    case pressuredForIntimateContent
    case threatenedSharing
    case inconsistentKeyInfo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .identityNotConfirmed: "身份尚未确认"
        case .moneyRequest: "出现转账 / 金钱要求"
        case .suspiciousLink: "收到可疑链接"
        case .pressuredForIntimateContent: "被催促发私密内容"
        case .threatenedSharing: "出现传播 / 威胁"
        case .inconsistentKeyInfo: "关键信息前后不一"
        }
    }

    var needsImmediatePause: Bool {
        self == .moneyRequest
            || self == .suspiciousLink
            || self == .pressuredForIntimateContent
            || self == .threatenedSharing
    }
}

// MARK: - 防护记录

enum ProtectionStatus: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case notRecorded
    case protected
    case partial
    case noProtection
    case notApplicable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notRecorded: "未记录"
        case .protected: "全程使用安全套 / 屏障"
        case .partial: "部分行为使用"
        case .noProtection: "未用安全套 / 屏障"
        case .notApplicable: "无对应行为"
        }
    }

    var symbolName: String {
        switch self {
        case .notRecorded: "minus.circle"
        case .protected: "checkmark.shield.fill"
        case .partial: "shield.lefthalf.filled"
        case .noProtection: "exclamationmark.shield.fill"
        case .notApplicable: "slash.circle"
        }
    }

    var compactLabel: String {
        switch self {
        case .notRecorded: "屏障未记"
        case .protected: "全程屏障"
        case .partial: "部分屏障"
        case .noProtection: "未用屏障"
        case .notApplicable: "无对应行为"
        }
    }

    var tint: Color {
        switch self {
        case .notRecorded, .notApplicable: .secondary
        case .protected: Color(red: 0.22, green: 0.70, blue: 0.56)
        case .partial: Color(red: 0.95, green: 0.62, blue: 0.25)
        case .noProtection: Color(red: 0.94, green: 0.42, blue: 0.34)
        }
    }

    var isRecorded: Bool { self != .notRecorded }

    /// 至少有一部分对应行为没有使用屏障，只用于提醒回看，不代表医学风险结论。
    var hasBarrierGap: Bool { self == .partial || self == .noProtection }
}

/// 只记录实际发生的行为，不从对象身份、性别或性取向推断。
enum IntimacyActivity: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case kissing
    case touching
    case oralGiving
    case oralReceiving
    case vaginalPenetration
    case analInsertive
    case analReceptive
    case toys
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kissing: "亲亲"
        case .touching: "上手"
        case .oralGiving: "口 · 我给她"
        case .oralReceiving: "口 · 她给我"
        case .vaginalPenetration: "做爱"
        case .analInsertive: "肛 · 我在上"
        case .analReceptive: "肛 · 我在下"
        case .toys: "玩具"
        case .other: "其他"
        }
    }
}

/// 防护与健康相关方式。它们作用不同，因此只做事实记录，不合成“安全分”。
enum SafetyMeasure: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case externalCondom
    case internalCondom
    case oralBarrier
    case prep
    case contraception
    case lubricant
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .externalCondom: "外用安全套"
        case .internalCondom: "内用安全套"
        case .oralBarrier: "口腔屏障"
        case .prep: "PrEP"
        case .contraception: "其他避孕"
        case .lubricant: "润滑剂"
        case .other: "其他"
        }
    }

    var isBarrier: Bool {
        self == .externalCondom || self == .internalCondom || self == .oralBarrier
    }
}

/// 用户对这一次边界沟通的主观回看，不替代双方当时的持续同意。
enum BoundaryFeeling: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case notRecorded
    case comfortable
    case adjusted
    case uncertain
    case concern

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notRecorded: "未记录"
        case .comfortable: "安心明确"
        case .adjusted: "中途有调整"
        case .uncertain: "有些不确定"
        case .concern: "需要回看"
        }
    }

    var symbolName: String {
        switch self {
        case .notRecorded: "minus.circle"
        case .comfortable: "checkmark.circle.fill"
        case .adjusted: "arrow.triangle.2.circlepath"
        case .uncertain: "questionmark.circle.fill"
        case .concern: "exclamationmark.circle.fill"
        }
    }

    var needsFollowUp: Bool { self == .uncertain || self == .concern }
}

/// 可能影响本人判断或体验的当时状态；不用于替他人判断同意能力。
enum PersonalState: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case clearheaded
    case drinking
    case tired
    case stressed
    case unwell
    case rushed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clearheaded: "清醒放松"
        case .drinking: "饮酒 / 其他物质"
        case .tired: "疲惫"
        case .stressed: "紧张或有压力"
        case .unwell: "身体不适"
        case .rushed: "时间仓促"
        }
    }
}

enum MeetAgainIntent: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case notRecorded
    case yes
    case maybe
    case no

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notRecorded: "未决定"
        case .yes: "还想约"
        case .maybe: "看情况"
        case .no: "不再约"
        }
    }
}

enum FollowUpKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case message
    case planMeet
    case accountSafety
    case testing
    case exposureConsult
    case pregnancy
    case symptomCheck
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .message: "回个消息"
        case .planMeet: "再约一次"
        case .accountSafety: "账号有点不对"
        case .testing: "去做检测"
        case .exposureConsult: "暴露咨询"
        case .pregnancy: "担心怀孕"
        case .symptomCheck: "留意身体"
        case .other: "其他"
        }
    }

    var symbolName: String {
        switch self {
        case .message: "message.fill"
        case .planMeet: "calendar.badge.plus"
        case .accountSafety: "lock.shield.fill"
        case .testing: "cross.case.fill"
        case .exposureConsult: "phone.badge.waveform.fill"
        case .pregnancy: "calendar.badge.exclamationmark"
        case .symptomCheck: "heart.text.square.fill"
        case .other: "checklist"
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
    /// 0 表示未记录，1...5 表示本人身体 / 情绪感受；不作为“表现评分”。
    var physicalRating: Int
    var emotionalRating: Int
    var chatProgress: ChatProgress
    var explicitContentComfort: ExplicitContentComfort
    var acceptedExplicitMedia: Set<ExplicitMedium>
    var conversationTopics: Set<ConversationTopic>
    var digitalBoundaries: Set<DigitalBoundary>
    var conversationSafetyFlags: Set<ConversationSafetyFlag>
    var activities: Set<IntimacyActivity>
    var boundaryFeeling: BoundaryFeeling
    var personalStates: Set<PersonalState>
    var protectionStatus: ProtectionStatus
    var safetyMeasures: Set<SafetyMeasure>
    var safetyNote: String
    var meetAgainIntent: MeetAgainIntent
    var followUpKinds: Set<FollowUpKind>
    var followUpDate: Date?
    var followUpNote: String
    var isFollowUpDone: Bool
    var note: String
    /// 这次留下的照片，存在本机沙盒
    var photoIDs: [String]

    init(
        id: UUID = UUID(),
        companionID: UUID,
        date: Date = Date(),
        kind: EncounterKind = .intimacy,
        cityID: String? = nil,
        place: String = "",
        cost: Double? = nil,
        physicalRating: Int = 0,
        emotionalRating: Int = 0,
        chatProgress: ChatProgress = .notRecorded,
        explicitContentComfort: ExplicitContentComfort = .notRecorded,
        acceptedExplicitMedia: Set<ExplicitMedium> = [],
        conversationTopics: Set<ConversationTopic> = [],
        digitalBoundaries: Set<DigitalBoundary> = [],
        conversationSafetyFlags: Set<ConversationSafetyFlag> = [],
        activities: Set<IntimacyActivity> = [],
        boundaryFeeling: BoundaryFeeling = .notRecorded,
        personalStates: Set<PersonalState> = [],
        protectionStatus: ProtectionStatus = .notRecorded,
        safetyMeasures: Set<SafetyMeasure> = [],
        safetyNote: String = "",
        meetAgainIntent: MeetAgainIntent = .notRecorded,
        followUpKinds: Set<FollowUpKind> = [],
        followUpDate: Date? = nil,
        followUpNote: String = "",
        isFollowUpDone: Bool = false,
        note: String = "",
        photoIDs: [String] = []
    ) {
        self.id = id
        self.companionID = companionID
        self.date = date
        self.kind = kind
        self.cityID = cityID
        self.place = place
        self.cost = cost
        self.physicalRating = physicalRating
        self.emotionalRating = emotionalRating
        self.chatProgress = chatProgress
        self.explicitContentComfort = explicitContentComfort
        self.acceptedExplicitMedia = acceptedExplicitMedia
        self.conversationTopics = conversationTopics
        self.digitalBoundaries = digitalBoundaries
        self.conversationSafetyFlags = conversationSafetyFlags
        self.activities = activities
        self.boundaryFeeling = boundaryFeeling
        self.personalStates = personalStates
        self.protectionStatus = protectionStatus
        self.safetyMeasures = safetyMeasures
        self.safetyNote = safetyNote
        self.meetAgainIntent = meetAgainIntent
        self.followUpKinds = followUpKinds
        self.followUpDate = followUpDate
        self.followUpNote = followUpNote
        self.isFollowUpDone = isFollowUpDone
        self.note = note
        self.photoIDs = photoIDs
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
        physicalRating = try c.decodeIfPresent(Int.self, forKey: .physicalRating) ?? 0
        emotionalRating = try c.decodeIfPresent(Int.self, forKey: .emotionalRating) ?? 0
        chatProgress = try c.decodeIfPresent(ChatProgress.self, forKey: .chatProgress) ?? .notRecorded
        explicitContentComfort = try c.decodeIfPresent(ExplicitContentComfort.self, forKey: .explicitContentComfort) ?? .notRecorded
        acceptedExplicitMedia = try c.decodeIfPresent(Set<ExplicitMedium>.self, forKey: .acceptedExplicitMedia) ?? []
        conversationTopics = try c.decodeIfPresent(Set<ConversationTopic>.self, forKey: .conversationTopics) ?? []
        digitalBoundaries = try c.decodeIfPresent(Set<DigitalBoundary>.self, forKey: .digitalBoundaries) ?? []
        conversationSafetyFlags = try c.decodeIfPresent(Set<ConversationSafetyFlag>.self, forKey: .conversationSafetyFlags) ?? []
        activities = try c.decodeIfPresent(Set<IntimacyActivity>.self, forKey: .activities) ?? []
        boundaryFeeling = try c.decodeIfPresent(BoundaryFeeling.self, forKey: .boundaryFeeling) ?? .notRecorded
        personalStates = try c.decodeIfPresent(Set<PersonalState>.self, forKey: .personalStates) ?? []
        protectionStatus = try c.decodeIfPresent(ProtectionStatus.self, forKey: .protectionStatus) ?? .notRecorded
        safetyMeasures = try c.decodeIfPresent(Set<SafetyMeasure>.self, forKey: .safetyMeasures) ?? []
        safetyNote = try c.decodeIfPresent(String.self, forKey: .safetyNote) ?? ""
        meetAgainIntent = try c.decodeIfPresent(MeetAgainIntent.self, forKey: .meetAgainIntent) ?? .notRecorded
        followUpKinds = try c.decodeIfPresent(Set<FollowUpKind>.self, forKey: .followUpKinds) ?? []
        followUpDate = try c.decodeIfPresent(Date.self, forKey: .followUpDate)
        followUpNote = try c.decodeIfPresent(String.self, forKey: .followUpNote) ?? ""
        isFollowUpDone = try c.decodeIfPresent(Bool.self, forKey: .isFollowUpDone) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        photoIDs = try c.decodeIfPresent([String].self, forKey: .photoIDs) ?? []
    }

    /// 仅对已填写的维度求平均，避免把“未记录”误作中性分。
    var experienceRating: Double? {
        let values = [physicalRating, emotionalRating].filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    var hasPendingFollowUp: Bool {
        !followUpKinds.isEmpty && !isFollowUpDone
    }

    var followUpSummary: String {
        FollowUpKind.allCases
            .filter { followUpKinds.contains($0) }
            .map(\.label)
            .joined(separator: "、")
    }

    var activitySummary: String {
        let ordered = IntimacyActivity.allCases.filter { activities.contains($0) }
        let visible = ordered.prefix(3).map(\.label).joined(separator: "、")
        let remaining = ordered.count - min(ordered.count, 3)
        return remaining > 0 ? "\(visible) 等 \(ordered.count) 项" : visible
    }

    var conversationSummary: String {
        var parts: [String] = []
        if chatProgress != .notRecorded { parts.append(chatProgress.label) }
        if explicitContentComfort != .notRecorded { parts.append("露骨内容：\(explicitContentComfort.label)") }
        if !acceptedExplicitMedia.isEmpty { parts.append(acceptedExplicitMediaSummary) }
        return parts.joined(separator: " · ")
    }

    var acceptedExplicitMediaSummary: String {
        ExplicitMedium.allCases
            .filter { acceptedExplicitMedia.contains($0) }
            .map(\.label)
            .joined(separator: "、")
    }

    var hasConversationSafetyConcern: Bool {
        conversationSafetyFlags.contains { $0.needsImmediatePause }
    }
}

// MARK: - 标签建议

enum TagSuggestions {
    static let common = [
        "好看", "会聊", "主动", "听话", "反差", "声好听", "身材好", "会打扮",
        "固定约", "偶尔约", "只约不聊", "能过夜", "不留宿", "得提前约",
        "同城", "异地", "周末", "夜猫子", "能喝", "不喝酒",
        "先确认再发图", "只聊文字", "不发私密图", "不截屏",
        "见面前聊套", "边界清楚", "沟通直接", "守时",
    ]
}
