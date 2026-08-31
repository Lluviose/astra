import Foundation
import UIKit

/// 把头像和照片存进 App 沙盒，不进系统相册、不主动上传；允许随设备 iCloud Backup 恢复。
enum MediaStore {

    private static let folderName = "AstraMedia"
    private static let jpegQuality: CGFloat = 0.72
    private static let photoMaxSide: CGFloat = 1600
    private static let avatarMaxSide: CGFloat = 720

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

    static func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).jpg")
    }

    @discardableResult
    static func save(image: UIImage, kind: Kind = .photo, id: String = UUID().uuidString) -> String? {
        let maxSide = kind == .avatar ? avatarMaxSide : photoMaxSide
        guard let data = jpegData(from: image, maxSide: maxSide) else { return nil }
        do {
            let target = url(for: id)
            try data.write(to: target, options: .atomic)
            markBackupEligible(target)
            return id
        } catch {
            return nil
        }
    }

    @discardableResult
    static func save(data: Data, id: String) -> Bool {
        do {
            let target = url(for: id)
            try data.write(to: target, options: .atomic)
            markBackupEligible(target)
            return true
        } catch {
            return false
        }
    }

    static func data(id: String) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    static func image(id: String) -> UIImage? {
        guard let data = data(id: id) else { return nil }
        return UIImage(data: data)
    }

    static func delete(id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
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
            return String(name.dropLast(4))
        })
    }

    static func collect(ids: [String]) -> [String: Data] {
        var payload: [String: Data] = [:]
        for id in ids {
            if let data = data(id: id) { payload[id] = data }
        }
        return payload
    }

    static func restore(_ payload: [String: Data]) {
        for (id, data) in payload {
            _ = save(data: data, id: id)
        }
    }

    static func gc(referenced: Set<String>) {
        let orphans = existingIDs().subtracting(referenced)
        delete(ids: Array(orphans))
    }

    enum Kind { case avatar, photo }

    static func jpegData(from image: UIImage, maxSide: CGFloat) -> Data? {
        let scaled = scale(image, maxSide: maxSide)
        return scaled.jpegData(compressionQuality: jpegQuality)
    }

    private static func scale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide, longest > 0 else { return image }
        let ratio = maxSide / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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
