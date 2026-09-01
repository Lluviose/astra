import PhotosUI
import SwiftUI
import UIKit

/// 从相册挑图（系统选择器，不必开完整相册权限）。
struct LibraryPhotoPicker: View {
    var title: String = "从相册选"
    /// `nil` 表示不设置应用层选择上限。
    var selectionLimit: Int? = 1
    var onImported: ([String]) -> Void

    @State private var items: [PhotosPickerItem] = []
    @State private var loadGeneration = UUID()

    var body: some View {
        PhotosPicker(
            selection: $items,
            maxSelectionCount: selectionLimit,
            matching: .images,
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
            if let data = try? await item.loadTransferable(type: Data.self) {
                let savedID = await Task.detached(priority: .userInitiated) {
                    MediaStore.saveOriginal(data: data)
                }.value
                guard loadGeneration == generation else {
                    if let savedID { MediaStore.delete(id: savedID) }
                    MediaStore.delete(ids: importedIDs)
                    return
                }
                if let savedID { importedIDs.append(savedID) }
            }
        }
        guard loadGeneration == generation else {
            MediaStore.delete(ids: importedIDs)
            return
        }
        items = []
        if !importedIDs.isEmpty { onImported(importedIDs) }
    }
}

/// 现场拍照。
struct CameraPicker: UIViewControllerRepresentable {
    var onData: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onData: onData, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onData: (Data) -> Void
        let onCancel: () -> Void

        init(onData: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onData = onData
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
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

struct PhotoThumb: View {
    let id: String
    var size: CGFloat = 72
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onTap?()
            } label: {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.12))
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

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
            }
        }
        .task(id: id) {
            image = MediaStore.image(id: id)
        }
    }
}

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

struct PhotoViewer: View {
    let ids: [String]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var didFinishLoading = false

    init(ids: [String], index: Int) {
        self.ids = ids
        let safeIndex = ids.isEmpty ? 0 : min(max(index, 0), ids.count - 1)
        _index = State(initialValue: safeIndex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else if !didFinishLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 34, weight: .light))
                        Text("照片无法读取")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.78))
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
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        if value.translation.width < -40 { step(1) }
                        if value.translation.width > 40 { step(-1) }
                    }
            )
            .task(id: index) { reload() }
        }
    }

    private func step(_ delta: Int) {
        guard !ids.isEmpty else { return }
        index = min(max(index + delta, 0), ids.count - 1)
    }

    private func reload() {
        image = nil
        didFinishLoading = false
        guard ids.indices.contains(index) else {
            didFinishLoading = true
            return
        }
        image = MediaStore.image(id: ids[index])
        didFinishLoading = true
    }
}

struct PhotoAddBar: View {
    /// `nil` 表示资料照或艳照不设上限；记录照片仍传入剩余数量。
    var selectionLimit: Int? = nil
    var onImported: ([String]) -> Void

    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 10) {
            LibraryPhotoPicker(
                title: "相册",
                selectionLimit: selectionLimit,
                onImported: onImported
            )
                .buttonStyle(.bordered)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                .buttonStyle(.bordered)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onData: { data in
                    showCamera = false
                    if let id = MediaStore.saveOriginal(data: data) {
                        onImported([id])
                    }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }
}

/// 头像专用：相册 / 拍照 / 去掉。
struct AvatarPickerRow: View {
    var hasPhoto: Bool
    var onImported: (String) -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PhotoAddBar(selectionLimit: 1) { ids in
                    if let id = ids.first {
                        onImported(id)
                    }
                    MediaStore.delete(ids: Array(ids.dropFirst()))
                }
                if hasPhoto {
                    Button("去掉照片", role: .destructive, action: onRemove)
                        .buttonStyle(.bordered)
                }
            }
            Text("照片只复制进星图，不进系统相册或开发者服务器，可随设备 iCloud Backup 恢复。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
