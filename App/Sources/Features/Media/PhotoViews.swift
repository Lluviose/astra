import AVKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 相册选择器返回的视频：按文件接收，直接拷进沙盒，不把整段视频读进内存。
private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let target = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: target)
            return PickedMovie(url: target)
        }
    }
}

/// 从相册挑图或视频（系统选择器，不必开完整相册权限）。
struct LibraryPhotoPicker: View {
    var title: String = "从相册选"
    /// `nil` 表示不设置应用层选择上限。
    var selectionLimit: Int? = 1
    var allowsVideo = true
    var onImported: ([String]) -> Void

    @State private var items: [PhotosPickerItem] = []
    @State private var loadGeneration = UUID()

    var body: some View {
        PhotosPicker(
            selection: $items,
            maxSelectionCount: selectionLimit,
            matching: allowsVideo ? .any(of: [.images, .videos]) : .images,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        ) {
            Label(title, systemImage: "photo.on.rectangle")
        }
        .onChange(of: items) { _, newItems in
            let generation = UUID()
            loadGeneration = generation
            Task { await load(newItems, generation: generation) }
        }
        .onDisappear { loadGeneration = UUID() }
    }

    @MainActor
    private func load(_ newItems: [PhotosPickerItem], generation: UUID) async {
        guard !newItems.isEmpty else { return }
        var importedIDs: [String] = []
        for item in newItems {
            guard loadGeneration == generation else {
                MediaStore.delete(ids: importedIDs)
                return
            }
            let savedID = await importItem(item)
            guard loadGeneration == generation else {
                if let savedID { MediaStore.delete(id: savedID) }
                MediaStore.delete(ids: importedIDs)
                return
            }
            if let savedID { importedIDs.append(savedID) }
        }
        guard loadGeneration == generation else {
            MediaStore.delete(ids: importedIDs)
            return
        }
        items = []
        if !importedIDs.isEmpty { onImported(importedIDs) }
    }

    /// 视频走文件拷贝，图片走原始字节；两者都不转码。
    private func importItem(_ item: PhotosPickerItem) async -> String? {
        let isMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isMovie, allowsVideo {
            guard let movie = try? await item.loadTransferable(type: PickedMovie.self) else { return nil }
            let id = await Task.detached(priority: .userInitiated) {
                MediaStore.saveVideo(at: movie.url)
            }.value
            try? FileManager.default.removeItem(at: movie.url)
            return id
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            MediaStore.saveOriginal(data: data)
        }.value
    }
}

/// 现场拍照或拍视频。
struct CameraPicker: UIViewControllerRepresentable {
    var allowsVideo = true
    var onData: (Data) -> Void
    var onVideo: ((URL) -> Void)? = nil
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        if allowsVideo {
            picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
            picker.videoQuality = .typeHigh
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onData: onData, onVideo: onVideo, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onData: (Data) -> Void
        let onVideo: ((URL) -> Void)?
        let onCancel: () -> Void

        init(onData: @escaping (Data) -> Void, onVideo: ((URL) -> Void)?, onCancel: @escaping () -> Void) {
            self.onData = onData
            self.onVideo = onVideo
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let movieURL = info[.mediaURL] as? URL, let onVideo {
                onVideo(movieURL)
                return
            }
            if let imageURL = info[.imageURL] as? URL,
               let data = try? Data(contentsOf: imageURL),
               UIImage(data: data) != nil {
                onData(data)
                return
            }
            if let image = info[.originalImage] as? UIImage,
               let data = image.pngData() {
                onData(data)
                return
            }
            onCancel()
        }
    }
}

/// 缩略图：图片按需降采样，视频取首帧并显示时长角标。点开才读原图 / 播放原视频。
/// `size` 为 nil 时撑满父视图（九宫格用）。
struct PhotoThumb: View {
    let id: String
    var size: CGFloat? = 72
    var cornerRadius: CGFloat = 12
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var image: UIImage?
    @State private var isVideo = false
    @State private var duration: Double?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onTap?()
            } label: {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle().fill(Color.secondary.opacity(0.12))
                            Image(systemName: isVideo ? "video" : "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: size, height: size)
                    .frame(maxWidth: size == nil ? CGFloat.infinity : nil, maxHeight: size == nil ? CGFloat.infinity : nil)
                    .clipped()

                    if isVideo {
                        MediaDurationBadge(seconds: duration)
                            .padding(5)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVideo ? "视频" : "照片")

            if onDelete != nil {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .offset(x: 4, y: -4)
                .accessibilityLabel("去掉")
            }
        }
        .task(id: id) {
            isVideo = MediaStore.isVideo(id: id)
            image = await MediaStore.thumbnail(id: id, maxPixel: (size ?? 200) >= 120 ? 640 : 320)
            duration = isVideo ? await MediaStore.videoDuration(id: id) : nil
        }
    }
}

/// 「0:42」这类视频时长角标；读不到时长只显示播放符号。
struct MediaDurationBadge: View {
    let seconds: Double?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
            if let seconds {
                Text(Self.format(seconds))
                    .monospacedDigit()
            }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.55), in: Capsule())
    }

    static func format(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let rest = total % 60
        if minutes >= 60 {
            return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, rest)
        }
        return String(format: "%d:%02d", minutes, rest)
    }
}

/// 横向一排缩略图，编辑器和小空间用。
struct PhotoStrip: View {
    let ids: [String]
    var editable: Bool = false
    var onDelete: ((String) -> Void)?
    var onOpen: ((Int) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(ids.enumerated()), id: \.offset) { index, id in
                    PhotoThumb(
                        id: id,
                        onTap: { onOpen?(index) },
                        onDelete: editable ? { onDelete?(id) } : nil
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// 三列九宫格，档案相册用；长按可删除，点开进查看器。格子随宽度自适应，始终正方形。
struct PhotoGrid: View {
    let ids: [String]
    var columns: Int = 3
    var spacing: CGFloat = 4
    var onDelete: ((String) -> Void)?
    var onOpen: ((Int) -> Void)?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(Array(ids.enumerated()), id: \.offset) { index, id in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        PhotoThumb(id: id, size: nil, cornerRadius: 8, onTap: { onOpen?(index) })
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contextMenu {
                        Button {
                            onOpen?(index)
                        } label: {
                            Label("查看", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        if let onDelete {
                            Button(role: .destructive) {
                                onDelete(id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
            }
        }
    }
}

/// 全屏查看器：左右分页，图片读原图并支持双指缩放 / 双击放大，视频用系统播放器。
struct PhotoViewer: View {
    let ids: [String]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(ids: [String], index: Int) {
        self.ids = ids
        let safeIndex = ids.isEmpty ? 0 : min(max(index, 0), ids.count - 1)
        _index = State(initialValue: safeIndex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if ids.isEmpty {
                    MediaUnavailableView()
                } else {
                    TabView(selection: $index) {
                        ForEach(Array(ids.enumerated()), id: \.offset) { offset, id in
                            MediaPage(id: id, isActive: offset == index)
                                .tag(offset)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text(ids.isEmpty ? "0 / 0" : "\(index + 1) / \(ids.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .haptic(.selection, trigger: index)
        }
    }
}

private struct MediaUnavailableView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34, weight: .light))
            Text("照片无法读取")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.78))
    }
}

/// 查看器里的一页：按种类决定读原图还是起播放器。
private struct MediaPage: View {
    let id: String
    let isActive: Bool

    @State private var kind: MediaKind?
    @State private var didResolve = false

    var body: some View {
        Group {
            switch kind {
            case .image?:
                ZoomableImage(id: id)
            case .video?:
                VideoPage(id: id, isActive: isActive)
            case nil:
                if didResolve {
                    MediaUnavailableView()
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .task(id: id) {
            kind = MediaStore.kind(id: id)
            didResolve = true
        }
    }
}

/// 原图查看：不降采样。双指缩放到 1～5 倍，双击在 1 倍与 2.5 倍之间切换，放大后可拖动。
private struct ZoomableImage: View {
    let id: String

    @State private var image: UIImage?
    @State private var didFinishLoading = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnify.simultaneously(with: drag))
                        .onTapGesture(count: 2) { toggleZoom() }
                        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: scale)
                        .accessibilityLabel("照片，双指缩放查看原图")
                } else if !didFinishLoading {
                    ProgressView().tint(.white)
                } else {
                    MediaUnavailableView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
        }
        .task(id: id) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
            image = await Task.detached(priority: .userInitiated) {
                MediaStore.image(id: id)
            }.value
            didFinishLoading = true
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, minScale * 0.8), maxScale * 1.2)
            }
            .onEnded { _ in
                scale = min(max(scale, minScale), maxScale)
                lastScale = scale
                if scale == minScale {
                    offset = .zero
                    lastOffset = .zero
                }
            }
    }

    /// 只有放大后才接管拖动，否则把手势留给分页。
    private var drag: some Gesture {
        DragGesture(minimumDistance: scale > 1 ? 0 : 1_000)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        Haptics.shared.play(.lightTap)
        if scale > 1 {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        } else {
            scale = 2.5
            lastScale = 2.5
        }
    }
}

/// 视频页：系统播放器，翻走就暂停，切回来重新对准。
private struct VideoPage: View {
    let id: String
    let isActive: Bool

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                MediaUnavailableView()
            }
        }
        .onAppear {
            guard player == nil, let url = MediaStore.videoURL(id: id) else { return }
            player = AVPlayer(url: url)
        }
        .onChange(of: isActive) { _, active in
            if !active { player?.pause() }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

/// 相册 / 拍照两个按钮；`allowsVideo` 关掉后只收图片（头像用）。
struct PhotoAddBar: View {
    /// `nil` 表示资料照或艳照不设上限；记录照片仍传入剩余数量。
    var selectionLimit: Int? = nil
    var allowsVideo = true
    var onImported: ([String]) -> Void

    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 10) {
            LibraryPhotoPicker(
                title: "相册",
                selectionLimit: selectionLimit,
                allowsVideo: allowsVideo,
                onImported: onImported
            )
            .glassActionStyle()

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    Haptics.shared.play(.lightTap)
                    showCamera = true
                } label: {
                    Label(allowsVideo ? "拍摄" : "拍照", systemImage: "camera")
                }
                .glassActionStyle()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                allowsVideo: allowsVideo,
                onData: { data in
                    showCamera = false
                    if let id = MediaStore.saveOriginal(data: data) {
                        onImported([id])
                    }
                },
                onVideo: { url in
                    showCamera = false
                    guard allowsVideo else { return }
                    let id = MediaStore.saveVideo(at: url)
                    try? FileManager.default.removeItem(at: url)
                    if let id { onImported([id]) }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }
}

/// 头像专用：相册 / 拍照 / 去掉。只收图片。
struct AvatarPickerRow: View {
    var hasPhoto: Bool
    var onImported: (String) -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PhotoAddBar(selectionLimit: 1, allowsVideo: false) { ids in
                    if let id = ids.first {
                        onImported(id)
                    }
                    MediaStore.delete(ids: Array(ids.dropFirst()))
                }
                if hasPhoto {
                    Button("去掉照片", role: .destructive, action: onRemove)
                        .glassActionStyle()
                        .tint(.red)
                }
            }
            Text("照片只复制进星图，不进系统相册或开发者服务器，可随设备 iCloud Backup 恢复。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
