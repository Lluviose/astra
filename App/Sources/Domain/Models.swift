import Foundation
import SwiftUI

// MARK: - 相处状态

enum RelationStage: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case new        // 刚认识
    case chatting   // 聊上了
    case flirting   // 暧昧中
    case prospect   // 准炮友
    case casual     // 炮友
    case regular    // 固定炮友
    case paused     // 先搁着
    case ended      // 结束了

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: "刚认识"
        case .chatting: "聊上了"
        case .flirting: "暧昧中"
        case .prospect: "准炮友"
        case .casual: "炮友"
        case .regular: "固定炮友"
        case .paused: "先搁着"
        case .ended: "结束了"
        }
    }

    var symbolName: String {
        switch self {
        case .new: "sparkles"
        case .chatting: "bubble.left.and.bubble.right.fill"
        case .flirting: "heart.text.square.fill"
        case .prospect: "bolt.heart.fill"
        case .casual: "flame.fill"
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
        case .prospect: Color(red: 0.96, green: 0.32, blue: 0.42)
        case .casual: Color(red: 0.94, green: 0.22, blue: 0.46)
        case .regular: Color(red: 0.67, green: 0.32, blue: 0.94)
        case .paused: Color(red: 0.36, green: 0.62, blue: 0.86)
        case .ended: Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    /// 排序权重：越接近稳定约越靠前
    var weight: Int {
        switch self {
        case .regular: 7
        case .casual: 6
        case .prospect: 5
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

// MARK: - 私密评分

enum CompanionScoreDimension: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case looks
    case body
    case chemistry
    case initiative
    case desire
    case afterglow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .looks: "颜值"
        case .body: "身材"
        case .chemistry: "床上默契"
        case .initiative: "主动感"
        case .desire: "欲望值"
        case .afterglow: "回味欲"
        }
    }

    var shortLabel: String {
        switch self {
        case .chemistry: "默契"
        case .initiative: "主动"
        case .afterglow: "回味"
        default: label
        }
    }

    var symbolName: String {
        switch self {
        case .looks: "eyes"
        case .body: "figure.stand"
        case .chemistry: "bolt.heart.fill"
        case .initiative: "bolt.fill"
        case .desire: "flame.fill"
        case .afterglow: "repeat.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .looks: Color(red: 0.92, green: 0.38, blue: 0.68)
        case .body: Color(red: 0.68, green: 0.34, blue: 0.94)
        case .chemistry: Color(red: 0.96, green: 0.29, blue: 0.50)
        case .initiative: Color(red: 0.96, green: 0.58, blue: 0.24)
        case .desire: Color(red: 0.92, green: 0.18, blue: 0.35)
        case .afterglow: Color(red: 0.48, green: 0.38, blue: 0.94)
        }
    }

    /// 综合分权重，总计 100。床上默契和欲望感更突出。
    var weight: Int {
        switch self {
        case .looks: 16
        case .body: 16
        case .chemistry: 24
        case .initiative: 12
        case .desire: 20
        case .afterglow: 12
        }
    }
}

struct CompanionScorecard: Codable, Hashable, Sendable {
    var looks: Int
    var body: Int
    var chemistry: Int
    var initiative: Int
    var desire: Int
    var afterglow: Int

    private enum CodingKeys: String, CodingKey {
        case looks
        case body
        case chemistry
        case initiative
        case desire
        case afterglow
    }

    init(
        looks: Int = 0,
        body: Int = 0,
        chemistry: Int = 0,
        initiative: Int = 0,
        desire: Int = 0,
        afterglow: Int = 0
    ) {
        self.looks = Self.clamp(looks)
        self.body = Self.clamp(body)
        self.chemistry = Self.clamp(chemistry)
        self.initiative = Self.clamp(initiative)
        self.desire = Self.clamp(desire)
        self.afterglow = Self.clamp(afterglow)
    }

    /// 允许旧备份只带部分维度；异常值会收进 0...10，避免一项坏数据拖垮整份档案。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            looks: try c.decodeIfPresent(Int.self, forKey: .looks) ?? 0,
            body: try c.decodeIfPresent(Int.self, forKey: .body) ?? 0,
            chemistry: try c.decodeIfPresent(Int.self, forKey: .chemistry) ?? 0,
            initiative: try c.decodeIfPresent(Int.self, forKey: .initiative) ?? 0,
            desire: try c.decodeIfPresent(Int.self, forKey: .desire) ?? 0,
            afterglow: try c.decodeIfPresent(Int.self, forKey: .afterglow) ?? 0
        )
    }

    static let empty = CompanionScorecard()

    static func balanced(fromLegacyRating rating: Int) -> CompanionScorecard {
        let value = min(max(rating * 2, 0), 10)
        return CompanionScorecard(
            looks: value,
            body: value,
            chemistry: value,
            initiative: value,
            desire: value,
            afterglow: value
        )
    }

    func value(for dimension: CompanionScoreDimension) -> Int {
        switch dimension {
        case .looks: looks
        case .body: body
        case .chemistry: chemistry
        case .initiative: initiative
        case .desire: desire
        case .afterglow: afterglow
        }
    }

    mutating func set(_ value: Int, for dimension: CompanionScoreDimension) {
        let clamped = Self.clamp(value)
        switch dimension {
        case .looks: looks = clamped
        case .body: body = clamped
        case .chemistry: chemistry = clamped
        case .initiative: initiative = clamped
        case .desire: desire = clamped
        case .afterglow: afterglow = clamped
        }
    }

    var completedCount: Int {
        CompanionScoreDimension.allCases.filter { value(for: $0) > 0 }.count
    }

    var overallScore: Int {
        let scored = CompanionScoreDimension.allCases.filter { value(for: $0) > 0 }
        guard !scored.isEmpty else { return 0 }
        let weightedTotal = scored.reduce(0) { result, dimension in
            result + value(for: dimension) * dimension.weight
        }
        let weightTotal = scored.reduce(0) { $0 + $1.weight }
        return Int((Double(weightedTotal) / Double(weightTotal) * 10).rounded())
    }

    var legacyStarRating: Int {
        min(max(Int((Double(overallScore) / 20).rounded()), 0), 5)
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, 0), 10)
    }
}

enum BustSize: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case notRecorded
    case aa
    case a
    case b
    case c
    case d
    case e
    case f
    case g
    case h
    case i
    case j
    case k

    var id: String { rawValue }

    var label: String {
        code.isEmpty ? "未记录" : "\(code) 杯"
    }

    var code: String {
        switch self {
        case .notRecorded: ""
        default: rawValue.uppercased()
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        // 兼容开发期曾写入的笼统 H+，迁移为明确的 H 杯。
        self = raw == "hPlus" ? .h : (Self(rawValue: raw) ?? .notRecorded)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    /// 六维私密评分。`rating` 继续保留，兼容旧备份与五星筛选。
    var scorecard: CompanionScorecard
    /// 头像照片，存在本机沙盒
    var photoID: String?
    /// 人物资料照，与艳照私藏分开。
    var profilePhotoIDs: [String]
    /// 档案里直接留下的私藏，不挂在某一次约上
    var albumPhotoIDs: [String]
    var age: Int?
    var heightCM: Int?
    /// 内衣尺码：下胸围 + 罩杯。
    var bustBandCM: Int?
    var bustSize: BustSize
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
        scorecard: CompanionScorecard? = nil,
        photoID: String? = nil,
        profilePhotoIDs: [String] = [],
        albumPhotoIDs: [String] = [],
        age: Int? = nil,
        heightCM: Int? = nil,
        bustBandCM: Int? = nil,
        bustSize: BustSize = .notRecorded,
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
        let resolvedScorecard = scorecard ?? .balanced(fromLegacyRating: rating)
        self.scorecard = resolvedScorecard
        self.rating = resolvedScorecard.legacyStarRating
        self.photoID = photoID
        self.profilePhotoIDs = profilePhotoIDs
        self.albumPhotoIDs = albumPhotoIDs
        self.age = age
        self.heightCM = heightCM
        self.bustBandCM = Self.normalizedBustBand(bustBandCM)
        self.bustSize = bustSize
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
        let legacyRating = min(max(try c.decodeIfPresent(Int.self, forKey: .rating) ?? 3, 0), 5)
        scorecard = try c.decodeIfPresent(CompanionScorecard.self, forKey: .scorecard)
            ?? .balanced(fromLegacyRating: legacyRating)
        rating = scorecard.legacyStarRating
        photoID = try c.decodeIfPresent(String.self, forKey: .photoID)
        profilePhotoIDs = try c.decodeIfPresent([String].self, forKey: .profilePhotoIDs) ?? []
        albumPhotoIDs = try c.decodeIfPresent([String].self, forKey: .albumPhotoIDs) ?? []
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        heightCM = try c.decodeIfPresent(Int.self, forKey: .heightCM)
        bustBandCM = Self.normalizedBustBand(try c.decodeIfPresent(Int.self, forKey: .bustBandCM))
        bustSize = try c.decodeIfPresent(BustSize.self, forKey: .bustSize) ?? .notRecorded
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

    var overallScore: Int { scorecard.overallScore }

    var bustSizeText: String? {
        if bustSize == .notRecorded {
            return bustBandCM.map { "\($0) cm（下胸围）" }
        }
        if let bustBandCM { return "\(bustBandCM)\(bustSize.code)" }
        return bustSize.label
    }

    private static func normalizedBustBand(_ value: Int?) -> Int? {
        guard let value else { return nil }
        let rounded = Int((Double(value) / 5).rounded()) * 5
        return min(max(rounded, 60), 110)
    }

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
    case intimacy
    case missed

    var id: String { rawValue }

    /// 新建记录只区分有没有发生关系。
    static var recordableCases: [EncounterKind] {
        [.intimacy, .missed]
    }

    var label: String {
        switch self {
        case .intimacy: "上床了"
        case .missed: "没上床"
        }
    }

    var symbolName: String {
        switch self {
        case .intimacy: "flame.fill"
        case .missed: "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .intimacy: Color(red: 0.94, green: 0.28, blue: 0.52)
        case .missed: Color(red: 0.35, green: 0.56, blue: 0.94)
        }
    }

    /// 是否属于需要展示防护记录的亲密事件。
    var isIntimate: Bool { self == .intimacy }

    var isMissed: Bool { self == .missed }
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
        case .protected: "全程戴套"
        case .partial: "中途摘了"
        case .noProtection: "无套"
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
        case .protected: "全程戴套"
        case .partial: "中途摘了"
        case .noProtection: "无套"
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
    case fingering
    case handjob
    case titjob
    case oralGiving
    case oralReceiving
    case sixtyNine
    case vaginalPenetration
    case analInsertive
    case analReceptive
    case cowgirl
    case doggy
    case missionary
    case standing
    case spooning
    case shower
    case car
    case outdoor
    case hotel
    case toys
    case multipleRounds
    case dirtyTalk
    case recorded
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kissing: "亲亲"
        case .touching: "上手"
        case .fingering: "手指进去"
        case .handjob: "她用手"
        case .titjob: "乳交"
        case .oralGiving: "口 · 我给她"
        case .oralReceiving: "口 · 她给我"
        case .sixtyNine: "69"
        case .vaginalPenetration: "做爱"
        case .analInsertive: "肛 · 我在上"
        case .analReceptive: "肛 · 我在下"
        case .cowgirl: "她骑上来"
        case .doggy: "后入"
        case .missionary: "正面"
        case .standing: "站着做"
        case .spooning: "侧躺"
        case .shower: "浴室"
        case .car: "车震"
        case .outdoor: "外面做"
        case .hotel: "开房"
        case .toys: "玩具"
        case .multipleRounds: "多轮"
        case .dirtyTalk: "叫床 / 说骚话"
        case .recorded: "拍了"
        case .other: "其他"
        }
    }

    var group: IntimacyActivityGroup {
        switch self {
        case .kissing, .touching, .fingering, .handjob, .titjob,
             .oralGiving, .oralReceiving, .sixtyNine,
             .vaginalPenetration, .analInsertive, .analReceptive, .toys, .other:
            .body
        case .cowgirl, .doggy, .missionary, .standing, .spooning:
            .position
        case .shower, .car, .outdoor, .hotel:
            .place
        case .multipleRounds, .dirtyTalk, .recorded:
            .heat
        }
    }
}

enum IntimacyActivityGroup: String, CaseIterable, Identifiable {
    case body
    case position
    case place
    case heat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .body: "身体"
        case .position: "姿势"
        case .place: "在哪做"
        case .heat: "更刺激的"
        }
    }
}

/// 这次怎么收的尾，和「做了什么」分开记。
enum ClimaxDetail: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case sheCame
    case sheMultiple
    case creampie
    case pullOut
    case condomFinish
    case swallow
    case facial
    case onChest
    case onBody
    case multiple
    case edging

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sheCame: "她高潮了"
        case .sheMultiple: "她高潮好几次"
        case .creampie: "内射"
        case .pullOut: "拔出来射"
        case .condomFinish: "射在套里"
        case .swallow: "口爆咽下去"
        case .facial: "颜射"
        case .onChest: "射在胸上"
        case .onBody: "射在身上"
        case .multiple: "我射了不止一次"
        case .edging: "一直吊着不让射"
        }
    }

    var tint: Color {
        switch self {
        case .creampie, .swallow, .facial: Color(red: 0.94, green: 0.22, blue: 0.46)
        case .sheCame, .sheMultiple: Color(red: 0.93, green: 0.39, blue: 0.60)
        default: Color(red: 0.95, green: 0.56, blue: 0.30)
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
    var activities: Set<IntimacyActivity>
    var climaxDetails: Set<ClimaxDetail>
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
        activities: Set<IntimacyActivity> = [],
        climaxDetails: Set<ClimaxDetail> = [],
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
        self.physicalRating = min(max(physicalRating, 0), 5)
        self.emotionalRating = min(max(emotionalRating, 0), 5)
        self.activities = activities
        self.climaxDetails = climaxDetails
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
        normalizeForOutcome()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        companionID = try c.decode(UUID.self, forKey: .companionID)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        kind = try c.decodeIfPresent(EncounterKind.self, forKey: .kind) ?? .missed
        cityID = try c.decodeIfPresent(String.self, forKey: .cityID)
        place = try c.decodeIfPresent(String.self, forKey: .place) ?? ""
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        physicalRating = min(max(try c.decodeIfPresent(Int.self, forKey: .physicalRating) ?? 0, 0), 5)
        emotionalRating = min(max(try c.decodeIfPresent(Int.self, forKey: .emotionalRating) ?? 0, 0), 5)
        activities = try c.decodeIfPresent(Set<IntimacyActivity>.self, forKey: .activities) ?? []
        climaxDetails = try c.decodeIfPresent(Set<ClimaxDetail>.self, forKey: .climaxDetails) ?? []
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
        normalizeForOutcome()
    }

    /// 结果是模型的硬边界：没上床的记录不能携带性行为、防护或身体感受字段。
    mutating func normalizeForOutcome() {
        guard kind.isMissed else {
            if protectionStatus == .notApplicable { protectionStatus = .notRecorded }
            return
        }

        activities = []
        climaxDetails = []
        boundaryFeeling = .notRecorded
        personalStates = []
        protectionStatus = .notApplicable
        safetyMeasures = []
        safetyNote = ""
        physicalRating = 0
        let allowedFollowUps: Set<FollowUpKind> = [.message, .planMeet, .accountSafety, .other]
        followUpKinds.formIntersection(allowedFollowUps)
        if followUpKinds.isEmpty {
            followUpDate = nil
            followUpNote = ""
            isFollowUpDone = false
        }
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

    var climaxSummary: String {
        ClimaxDetail.allCases
            .filter { climaxDetails.contains($0) }
            .map(\.label)
            .joined(separator: "、")
    }

}

// MARK: - 标签建议

enum TagSuggestions {
    static let common = [
        "好看", "胸好", "腰细", "腿长", "会叫", "水多", "紧", "口活好",
        "主动", "听话", "反差", "声好听", "身材好", "会打扮", "黑丝", "制服",
        "准炮友", "炮友", "固定炮友", "只约不聊", "能过夜", "不留宿", "得提前约",
        "无套", "内射", "能口爆", "能颜射", "多轮", "会骑",
        "同城", "异地", "周末", "夜猫子", "能喝", "不喝酒",
        "先确认再发图", "只聊文字", "不发私密图", "不截屏",
        "见面前聊套", "边界清楚", "沟通直接", "守时",
    ]
}
