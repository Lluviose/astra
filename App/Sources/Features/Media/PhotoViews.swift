import PhotosUI
import SwiftUI
import UIKit

/// 从相册挑图（系统选择器，不必开完整相册权限）。
struct LibraryPhotoPicker: View {
    var title: String = "从相册选"
    var selectionLimit: Int = 1
    var onPicked: ([UIImage]) -> Void

    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(
            selection: $items,
            maxSelectionCount: max(1, selectionLimit),
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(title, systemImage: "photo.on.rectangle")
        }
        .onChange(of: items) { _, newItems in
            Task { await load(newItems) }
        }
    }

    @MainActor
    private func load(_ newItems: [PhotosPickerItem]) async {
        guard !newItems.isEmpty else { return }
        var images: [UIImage] = []
        for item in newItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        items = []
        if !images.isEmpty { onPicked(images) }
    }
}

/// 现场拍照。
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
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
            HStack(spacing: 8) {
                ForEach(Array(ids.enumerated()), id: \.element) { index, id in
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

    init(ids: [String], index: Int) {
        self.ids = ids
        _index = State(initialValue: index)
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
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("\(index + 1) / \(ids.count)")
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
        guard ids.indices.contains(index) else { return }
        image = MediaStore.image(id: ids[index])
    }
}

struct PhotoAddBar: View {
    var remaining: Int
    var onPicked: ([UIImage]) -> Void

    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 10) {
            LibraryPhotoPicker(title: "相册", selectionLimit: max(1, remaining), onPicked: onPicked)
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
                onImage: { image in
                    showCamera = false
                    onPicked([image])
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
    var onPicked: (UIImage) -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PhotoAddBar(remaining: 1) { images in
                    if let image = images.first { onPicked(image) }
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
