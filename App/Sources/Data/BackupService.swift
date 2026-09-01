import Foundation

/// 备份文件格式。整个 App 唯一的「数据出口」——只写到你自己选的位置，不经过任何服务器。
struct BackupPayload: Codable, Sendable {
    var format: String
    var version: Int
    var exportedAt: Date
    var companions: [Companion]
    var encounters: [Encounter]
    /// JPEG 二进制，key 是 MediaStore 的 id。v1 备份没有这一项。
    var media: [String: Data]

    init(
        companions: [Companion],
        encounters: [Encounter],
        media: [String: Data] = [:],
        exportedAt: Date = Date()
    ) {
        self.format = BackupService.formatIdentifier
        self.version = BackupService.currentVersion
        self.exportedAt = exportedAt
        self.companions = companions
        self.encounters = encounters
        self.media = media
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        companions = try c.decodeIfPresent([Companion].self, forKey: .companions) ?? []
        encounters = try c.decodeIfPresent([Encounter].self, forKey: .encounters) ?? []
        media = try c.decodeIfPresent([String: Data].self, forKey: .media) ?? [:]
    }
}

enum BackupError: LocalizedError {
    case notAnAstraBackup
    case unsupportedVersion(Int)
    case invalidContents(String)
    case cannotRestoreMedia
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notAnAstraBackup: "这不是星图的备份文件。"
        case .unsupportedVersion(let version): "备份版本 \(version) 比当前 App 更新，请先升级星图。"
        case .invalidContents(let reason): "备份内容不完整：\(reason)"
        case .cannotRestoreMedia: "照片无法完整写入，请检查设备剩余空间后重试；本机档案尚未替换。"
        case .unreadable: "文件读不出来，可能已损坏。"
        }
    }
}

enum BackupService {

    static let formatIdentifier = "astra.backup"
    /// v4 replaces the old event taxonomy with the two result outcomes: intimacy / missed.
    static let currentVersion = 4

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode(
        companions: [Companion],
        encounters: [Encounter],
        media: [String: Data] = [:]
    ) throws -> Data {
        try encoder.encode(BackupPayload(companions: companions, encounters: encounters, media: media))
    }

    static func decode(_ data: Data) throws -> BackupPayload {
        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else {
            throw BackupError.unreadable
        }
        guard payload.format == formatIdentifier else { throw BackupError.notAnAstraBackup }
        guard payload.version <= currentVersion else { throw BackupError.unsupportedVersion(payload.version) }
        try validate(payload)
        return payload
    }

    private static func validate(_ payload: BackupPayload) throws {
        guard payload.version >= 1 else {
            throw BackupError.invalidContents("版本号无效。")
        }

        let companionIDs = payload.companions.map(\.id)
        guard Set(companionIDs).count == companionIDs.count else {
            throw BackupError.invalidContents("存在重复的对象档案。")
        }

        let encounterIDs = payload.encounters.map(\.id)
        guard Set(encounterIDs).count == encounterIDs.count else {
            throw BackupError.invalidContents("存在重复的记录。")
        }

        let knownCompanionIDs = Set(companionIDs)
        guard payload.encounters.allSatisfy({ knownCompanionIDs.contains($0.companionID) }) else {
            throw BackupError.invalidContents("有记录找不到对应对象。")
        }

        let referencedMediaIDs = mediaIDs(
            companions: payload.companions,
            encounters: payload.encounters
        )
        guard referencedMediaIDs.allSatisfy(MediaStore.isValidID),
              payload.media.keys.allSatisfy(MediaStore.isValidID)
        else {
            throw BackupError.invalidContents("照片标识无效。")
        }
    }

    private static func mediaIDs(companions: [Companion], encounters: [Encounter]) -> Set<String> {
        var ids = Set(companions.compactMap(\.photoID))
        for companion in companions {
            ids.formUnion(companion.profilePhotoIDs)
            ids.formUnion(companion.albumPhotoIDs)
        }
        for encounter in encounters {
            ids.formUnion(encounter.photoIDs)
        }
        return ids
    }

    /// astra-backup-2026-08-31.json
    static func suggestedFilename(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "astra-backup-\(formatter.string(from: date))"
    }
}
