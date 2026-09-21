import AVFoundation
import Foundation
import ImageIO
import UIKit

/// 媒体文件的种类，由沙盒里的扩展名决定；旧文件一律是 jpg 图片。
enum MediaKind: String, Sendable {
    case image
    case video
}

/// 把头像、照片和视频存进 App 沙盒，不进系统相册、不主动上传；允许随设备 iCloud Backup 恢复。
///
/// 产品约束：用户挑的照片按原始字节保存，查看大图时也读原图；缩略图只是列表用的临时降采样副本。
/// 视频原样落盘，不转码。
enum MediaStore {

    private static let folderName = "AstraMedia"
    /// 图片一律用 jpg 扩展名存（内容可能是 PNG 原图，读取时按字节判断）；视频按来源保留 mov / mp4。
    private static let imageExtension = "jpg"
    static let videoExtensions: [String] = ["mov", "mp4"]
    private static let knownExtensions: [String] = ["jpg", "mov", "mp4"]
    private static let allowedIDCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    )
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()

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

    // MARK: - 写入

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

    /// 图片写入；同一 ID 若之前存的是视频，会先清掉旧文件，保证一个 ID 只对应一个文件。
    @discardableResult
    static func save(data: Data, id: String) -> Bool {
        write(data: data, id: id, extension: imageExtension)
    }

    /// 视频原样落盘，不转码；扩展名只接受 mov / mp4，其它一律拒绝。
    @discardableResult
    static func saveVideo(data: Data, id: String = UUID().uuidString, fileExtension: String) -> String? {
        guard let ext = normalizedVideoExtension(fileExtension), !data.isEmpty else { return nil }
        return write(data: data, id: id, extension: ext) ? id : nil
    }

    /// 相册 / 相机给的是临时文件 URL 时直接拷贝，避免把整段视频读进内存。
    @discardableResult
    static func saveVideo(at sourceURL: URL, id: String = UUID().uuidString) -> String? {
        guard let ext = normalizedVideoExtension(sourceURL.pathExtension),
              let target = fileURL(for: id, extension: ext)
        else { return nil }
        removeAllVariants(of: id)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: target)
            markBackupEligible(target)
            return id
        } catch {
            return nil
        }
    }

    // MARK: - 读取

    static func data(id: String) -> Data? {
        guard let target = existingFileURL(for: id) else { return nil }
        return try? Data(contentsOf: target)
    }

    /// 原图读取：不降采样、不重编码，查看大图和导出备份都走这里。
    static func image(id: String) -> UIImage? {
        guard kind(id: id) == .image, let data = data(id: id) else { return nil }
        return UIImage(data: data)
    }

    /// 视频播放用的文件 URL；不是视频就返回 nil。
    static func videoURL(id: String) -> URL? {
        guard kind(id: id) == .video else { return nil }
        return existingFileURL(for: id)
    }

    static func kind(id: String) -> MediaKind? {
        guard let url = existingFileURL(for: id) else { return nil }
        return videoExtensions.contains(url.pathExtension.lowercased()) ? .video : .image
    }

    static func isVideo(id: String) -> Bool { kind(id: id) == .video }

    /// 沙盒里这个 ID 的扩展名；图片是 jpg，视频是 mov / mp4，不存在返回 nil。
    static func fileExtension(id: String) -> String? {
        existingFileURL(for: id)?.pathExtension.lowercased()
    }

    /// 视频时长（秒）；不是视频或读不出来返回 nil。
    static func videoDuration(id: String) async -> Double? {
        guard let url = videoURL(id: id) else { return nil }
        guard let duration = try? await AVURLAsset(url: url).load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : nil
    }

    /// 列表和网格用的小图：图片用 ImageIO 按需降采样，视频取首帧；结果进内存缓存。
    /// 只影响缩略图，原图仍按原始字节保存和查看。
    static func thumbnail(id: String, maxPixel: CGFloat = 320) async -> UIImage? {
        let key = cacheKey(id: id, maxPixel: maxPixel)
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let url = existingFileURL(for: id) else { return nil }
        let isVideo = videoExtensions.contains(url.pathExtension.lowercased())
        let image: UIImage? = await Task.detached(priority: .utility) {
            if isVideo {
                return await videoFrame(at: url, maxPixel: maxPixel)
            }
            return downsampledImage(at: url, maxPixel: maxPixel)
        }.value
        if let image { thumbnailCache.setObject(image, forKey: key) }
        return image
    }

    /// 同步版降采样，给测试和不方便 async 的地方用；只处理图片。
    static func downsampledImage(id: String, maxPixel: CGFloat) -> UIImage? {
        guard kind(id: id) == .image, let url = existingFileURL(for: id) else { return nil }
        return downsampledImage(at: url, maxPixel: maxPixel)
    }

    // MARK: - 删除与清点

    static func delete(id: String) {
        removeAllVariants(of: id)
        for size: CGFloat in [160, 320, 640, 1200] {
            thumbnailCache.removeObject(forKey: cacheKey(id: id, maxPixel: size))
        }
    }

    static func delete(ids: [String]) {
        ids.forEach(delete(id:))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        thumbnailCache.removeAllObjects()
        _ = directory
    }

    static func existingIDs() -> Set<String> {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(files.compactMap { name in
            let url = URL(fileURLWithPath: name)
            guard knownExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            let id = url.deletingPathExtension().lastPathComponent
            return isValidID(id) ? id : nil
        })
    }

    /// 全部媒体文件占用的字节数，设置页展示用。
    static func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.reduce(Int64(0)) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    // MARK: - 备份

    static func collect(ids: [String]) -> [String: Data] {
        var payload: [String: Data] = [:]
        for id in ids {
            if let data = data(id: id) { payload[id] = data }
        }
        return payload
    }

    /// 备份里只需要标记非图片的扩展名；缺省即 jpg 图片，旧备份不带这一项也能还原。
    static func collectExtensions(ids: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for id in ids {
            if let ext = fileExtension(id: id), ext != imageExtension { result[id] = ext }
        }
        return result
    }

    /// 返回没能写入的媒体 ID。合并导入默认不覆盖已经存在的本机文件，避免旧备份
    /// 用碰巧相同的 ID 改写较新的照片。
    @discardableResult
    static func restore(
        _ payload: [String: Data],
        extensions: [String: String] = [:],
        overwriteExisting: Bool = true
    ) -> Set<String> {
        var failed = Set<String>()
        for (id, data) in payload {
            if !overwriteExisting, fileExists(id: id) { continue }
            if let ext = extensions[id] {
                if saveVideo(data: data, id: id, fileExtension: ext) == nil { failed.insert(id) }
            } else if !save(data: data, id: id) {
                failed.insert(id)
            }
        }
        return failed
    }

    static func gc(referenced: Set<String>) {
        let orphans = existingIDs().subtracting(referenced)
        delete(ids: Array(orphans))
    }

    // MARK: - 私有

    private static func cacheKey(id: String, maxPixel: CGFloat) -> NSString {
        "\(id)#\(Int(maxPixel))" as NSString
    }

    private static func fileURL(for id: String, extension ext: String) -> URL? {
        guard isValidID(id) else { return nil }
        return directory.appendingPathComponent(id).appendingPathExtension(ext)
    }

    /// 同一 ID 只应有一个文件；按 jpg → mov → mp4 顺序找到第一个存在的。
    private static func existingFileURL(for id: String) -> URL? {
        guard isValidID(id) else { return nil }
        let fileManager = FileManager.default
        for ext in knownExtensions {
            let url = directory.appendingPathComponent(id).appendingPathExtension(ext)
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private static func fileExists(id: String) -> Bool {
        existingFileURL(for: id) != nil
    }

    private static func write(data: Data, id: String, extension ext: String) -> Bool {
        guard let target = fileURL(for: id, extension: ext) else { return false }
        removeAllVariants(of: id)
        do {
            try data.write(to: target, options: .atomic)
            markBackupEligible(target)
            return true
        } catch {
            return false
        }
    }

    private static func removeAllVariants(of id: String) {
        guard isValidID(id) else { return }
        for ext in knownExtensions {
            let url = directory.appendingPathComponent(id).appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func normalizedVideoExtension(_ raw: String) -> String? {
        let ext = raw.lowercased()
        return videoExtensions.contains(ext) ? ext : nil
    }

    private static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func videoFrame(at url: URL, maxPixel: CGFloat) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: result.image)
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
