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
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notAnAstraBackup: "这不是星图的备份文件。"
        case .unsupportedVersion(let version): "备份版本 \(version) 比当前 App 更新，请先升级星图。"
        case .unreadable: "文件读不出来，可能已损坏。"
        }
    }
}

enum BackupService {

    static let formatIdentifier = "astra.backup"
    /// v3 adds six-dimensional scores, explicit bust size and separate profile-photo references.
    static let currentVersion = 3

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
        return payload
    }

    /// astra-backup-2026-08-31.json
    static func suggestedFilename(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "astra-backup-\(formatter.string(from: date))"
    }
}
