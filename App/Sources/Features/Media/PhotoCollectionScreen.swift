import SwiftUI
import UIKit

/// All explicitly collected photos, including people without intimate records.
struct PhotoCollectionScreen: View {
    var collectionOnly = true
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selection: UUID?
    @State private var viewerIDs: [String] = []
    @State private var showsViewer = false

    private var people: [Companion] {
        (collectionOnly ? app.conqueredCompanions : app.companions).filter { !app.albumIDs(for: $0.id).isEmpty }
            .sorted { app.lastContact(for: $0) > app.lastContact(for: $1) }
    }
    private var displayed: [Companion] { people.filter { selection == nil || selection == $0.id } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                PageMasthead(eyebrow: "COLLECTION", title: "片刻，有了形状", subtitle: collectionOnly ? "后宫人物的私藏与相处照片。" : "来自全部人物相册与相处记录。")
                if !app.namesRevealed {
                    EmptyStateView(symbol: "eye.slash", title: "照片已隐藏", message: "显示代号与照片后，可以继续翻阅。",
                                   actionTitle: "显示照片", action: { app.toggleNamesRevealed() })
                        .astraSurface()
                } else if people.isEmpty {
                    EmptyStateView(symbol: "photo", title: "相册还没有照片",
                                   message: "在任意人物档案或相处记录里添加照片，它们会汇集在这里。")
                        .astraSurface()
                } else {
                    Menu {
                        Picker("人物", selection: $selection) {
                            Text("全部人物").tag(UUID?.none)
                            ForEach(people) { Text($0.displayName).tag(Optional($0.id)) }
                        }
                    } label: {
                        Label(selection.flatMap { app.companion(id: $0)?.displayName } ?? "全部人物", systemImage: "line.3.horizontal.decrease")
                            .font(.subheadline).frame(minHeight: 44)
                    }
                    ForEach(displayed) { person in
                        let ids = app.albumIDs(for: person.id)
                        VStack(alignment: .leading, spacing: 14) {
                            NavigationLink(value: person.id) {
                                HStack(spacing: 10) {
                                    AvatarView(companion: person, size: 32, showRing: false)
                                    Text(person.displayName).font(.headline)
                                    Spacer()
                                    Text("\(ids.count) 张").font(.caption).foregroundStyle(Palette.secondaryInk)
                                    ChevronHint()
                                }
                            }
                            .buttonStyle(.plain)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 145), spacing: 10)], spacing: 10) {
                                ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                                    Button {
                                        viewerIDs = Array(ids[index...]) + Array(ids[..<index])
                                        showsViewer = true
                                    } label: { CollectionPhoto(id: id) }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(person.displayName)的照片，第 \(index + 1) 张")
                                }
                            }
                        }
                    }
                }
            }
            .padding(AstraLayout.gutter).astraContentMargins()
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("私藏相册").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { PrivacyButton() } }
        .fullScreenCover(isPresented: $showsViewer) { PhotoViewer(ids: viewerIDs, index: 0) }
        .onChange(of: app.namesRevealed) { _, revealed in if !revealed { showsViewer = false } }
    }
}

private struct CollectionPhoto: View {
    let id: String
    @State private var image: UIImage?
    var body: some View {
        Rectangle().fill(Palette.surfaceSecondary)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFill() }
                else { Image(systemName: "photo").foregroundStyle(Palette.secondaryInk) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .task(id: id) { image = MediaStore.image(id: id) }
    }
}
