import Foundation
import UIKit

/// 把头像和照片存进 App 沙盒，不进系统相册、不主动上传；允许随设备 iCloud Backup 恢复。
enum MediaStore {

    private static let folderName = "AstraMedia"
    private static let allowedIDCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    )
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        markBackupEligible(url)
        return url
    }

    /// 清除旧版本写下的「排除备份」标记，让全部持久化用户文件进入系统设备备份。
    /// Caches / tmp 仍遵循 iOS 自身规则；本 App 的档案、设置与照片都不依赖它们。
    static func enableSystemBackup() {
        let fileManager = FileManager.default
        _ = directory // 确保照片目录已经存在。

        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let preferences = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Preferences", isDirectory: true)

        for root in [applicationSupport, documents, preferences].compactMap({ $0 })
            where fileManager.fileExists(atPath: root.path) {
            markTreeBackupEligible(root)
        }
    }

    /// 媒体 ID 既来自本机 UUID，也可能来自用户导入的备份；必须先限制为纯文件名，
    /// 避免 `../`、路径分隔符或异常长 key 越出 AstraMedia 目录。
    static func isValidID(_ id: String) -> Bool {
        guard (1...128).contains(id.utf8.count) else { return false }
        return id.unicodeScalars.allSatisfy { allowedIDCharacters.contains($0) }
    }

    /// 产品约束：用户挑选的照片属于原始档案，不得降采样或重新编码。
    /// 保存相册选择器返回的源文件字节，以保留原始分辨率、编码质量与元数据。
    @discardableResult
    static func saveOriginal(data: Data, id: String = UUID().uuidString) -> String? {
        guard UIImage(data: data) != nil else { return nil }
        return save(data: data, id: id) ? id : nil
    }

    /// 相机未提供源文件 URL 时的无损兜底。保留完整像素尺寸，不做降采样。
    @discardableResult
    static func saveLossless(image: UIImage, id: String = UUID().uuidString) -> String? {
        guard let data = image.pngData() else { return nil }
        return save(data: data, id: id) ? id : nil
    }

    @discardableResult
    static func save(data: Data, id: String) -> Bool {
        guard let target = fileURL(for: id) else { return false }
        do {
            try data.write(to: target, options: .atomic)
            markBackupEligible(target)
            return true
        } catch {
            return false
        }
    }

    static func data(id: String) -> Data? {
        guard let target = fileURL(for: id) else { return nil }
        return try? Data(contentsOf: target)
    }

    static func image(id: String) -> UIImage? {
        guard let data = data(id: id) else { return nil }
        return UIImage(data: data)
    }

    static func delete(id: String) {
        guard let target = fileURL(for: id) else { return }
        try? FileManager.default.removeItem(at: target)
    }

    static func delete(ids: [String]) {
        ids.forEach(delete(id:))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        _ = directory
    }

    static func existingIDs() -> Set<String> {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(files.compactMap { name in
            guard name.hasSuffix(".jpg") else { return nil }
            let id = String(name.dropLast(4))
            return isValidID(id) ? id : nil
        })
    }

    static func collect(ids: [String]) -> [String: Data] {
        var payload: [String: Data] = [:]
        for id in ids {
            if let data = data(id: id) { payload[id] = data }
        }
        return payload
    }

    /// 返回没能写入的媒体 ID。合并导入默认不覆盖已经存在的本机文件，避免旧备份
    /// 用碰巧相同的 ID 改写较新的照片。
    @discardableResult
    static func restore(_ payload: [String: Data], overwriteExisting: Bool = true) -> Set<String> {
        var failed = Set<String>()
        for (id, data) in payload {
            if !overwriteExisting, fileExists(id: id) { continue }
            if !save(data: data, id: id) { failed.insert(id) }
        }
        return failed
    }

    static func gc(referenced: Set<String>) {
        let orphans = existingIDs().subtracting(referenced)
        delete(ids: Array(orphans))
    }

    private static func fileURL(for id: String) -> URL? {
        guard isValidID(id) else { return nil }
        return directory.appendingPathComponent(id).appendingPathExtension("jpg")
    }

    private static func fileExists(id: String) -> Bool {
        guard let target = fileURL(for: id) else { return false }
        return FileManager.default.fileExists(atPath: target.path)
    }

    private static func markBackupEligible(_ url: URL) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = false
        var mutable = url
        try? mutable.setResourceValues(values)
    }

    private static func markTreeBackupEligible(_ root: URL) {
        markBackupEligible(root)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isExcludedFromBackupKey]
        ) else { return }
        for case let url as URL in enumerator {
            markBackupEligible(url)
        }
    }
}
