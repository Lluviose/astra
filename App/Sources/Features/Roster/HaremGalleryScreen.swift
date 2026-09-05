import SwiftUI
import UIKit

/// A personal collection, presented as a photographic cabinet rather than a score table.
struct HaremGalleryScreen: View {
    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var flow = RecordingFlow()
    @State private var path = NavigationPath()
    @State private var viewingPhotos: [String] = []
    @State private var showsPhotos = false
    @State private var favoritesOnly = false
    @State private var sort: CollectionSort = .recent

    private enum CollectionSort: String, CaseIterable, Identifiable {
        case recent = "最近相处", tier = "收藏层级", desire = "欲望评分"
        var id: String { rawValue }
    }
    private var collection: [Companion] {
        app.conqueredCompanions.filter { !favoritesOnly || $0.isPinned }.sorted { lhs, rhs in
            switch sort {
            case .recent: return app.lastContact(for: lhs) > app.lastContact(for: rhs)
            case .tier: return app.hookupCount(for: lhs.id) > app.hookupCount(for: rhs.id)
            case .desire: return lhs.scorecard.desire > rhs.scorecard.desire
            }
        }
    }
    private var featured: Companion? {
        guard !favoritesOnly else { return nil }
        let favorites = collection.filter(\.isPinned)
        let source = favorites.isEmpty ? collection : favorites
        guard !source.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return source[day % source.count]
    }
    private var gridPeople: [Companion] { collection.filter { $0.id != featured?.id } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    masthead
                    if app.conqueredCompanions.isEmpty {
                        emptyCollection
                    } else {
                        controls
                        if let featured {
                            Button {
                                let photos = app.albumIDs(for: featured.id)
                                if app.namesRevealed, !photos.isEmpty {
                                    viewingPhotos = photos
                                    showsPhotos = true
                                } else { path.append(featured.id) }
                            } label: {
                                portraitCard(featured, height: typeSize.isAccessibilitySize ? 420 : 340, featured: true)
                            }
                            .buttonStyle(HapticButtonStyle(scale: 0.99))
                            .accessibilityIdentifier("featured-person")
                            NavigationLink(value: featured.id) {
                                HStack {
                                    Text("打开她的档案").font(.caption)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }.frame(minHeight: 44)
                            }
                            .accessibilityIdentifier("featured-dossier")
                            .foregroundStyle(Palette.accent)
                        }
                        if collection.isEmpty {
                            EmptyStateView(symbol: "heart", title: "还没有偏爱人物",
                                           message: "在她的档案中置顶，就会收进这里。",
                                           actionTitle: "查看全部后宫", action: { favoritesOnly = false })
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 280 : 150), spacing: 14)], spacing: 20) {
                            ForEach(gridPeople) { person in
                                NavigationLink(value: person.id) {
                                    portraitCard(person, height: typeSize.isAccessibilitySize ? 340 : 236)
                                }
                                .buttonStyle(HapticButtonStyle(scale: 0.985))
                            }
                        }
                    }
                    adaptiveControls {
                        NavigationLink { RosterScreen() } label: {
                            Label("全部名册", systemImage: "person.2").frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .accessibilityIdentifier("open-roster")
                        NavigationLink { PhotoCollectionScreen() } label: {
                            Label("私藏相册", systemImage: "rectangle.stack").frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .accessibilityIdentifier("open-collection")
                    }
                    .font(.subheadline.weight(.medium)).buttonStyle(.plain)
                    .foregroundStyle(Palette.accent).astraSurface(cornerRadius: 18)
                }
                .padding(AstraLayout.gutter).padding(.bottom, 12).astraContentMargins()
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("后宫").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SettingsButton() }
                ToolbarItem(placement: .topBarTrailing) { PrivacyButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { flow.begin(kind: .intimacy, app: app) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("记录新的战绩")
                        .accessibilityIdentifier("collection-record")
                }
            }
            .navigationDestination(for: UUID.self) { CompanionDetailView(companionID: $0) }
        }
        .recordingFlowSheets(flow)
        .fullScreenCover(isPresented: $showsPhotos) { PhotoViewer(ids: viewingPhotos, index: 0) }
        .onChange(of: app.namesRevealed) { _, revealed in if !revealed { showsPhotos = false } }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THE PRIVATE COLLECTION").font(.caption2.monospaced()).tracking(2.5).foregroundStyle(Palette.accent)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Text("你的后宫")
                    .font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.ink)
                Spacer()
                Text(String(format: "%02d", app.conqueredCompanions.count))
                    .font(.system(.largeTitle, design: .serif)).foregroundStyle(Palette.accent)
                    .accessibilityLabel("\(app.conqueredCompanions.count) 位后宫人物")
            }
            Text(app.conqueredCompanions.isEmpty ? "从第一次亲密，到值得反复回味的收藏。" : "\(app.privateCollectionCount) 张私藏 · \(app.stats.totalIntimacyCount) 次亲密记录")
                .font(.subheadline).foregroundStyle(Palette.secondaryInk)
        }
        .padding(.vertical, 8)
    }

    private var controls: some View {
        adaptiveControls {
            Button { favoritesOnly.toggle() } label: {
                Label(favoritesOnly ? "只看偏爱" : "全部收藏", systemImage: favoritesOnly ? "heart.fill" : "square.grid.2x2")
                    .font(.subheadline).frame(minHeight: 44)
            }
            .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
            if !typeSize.isAccessibilitySize { Spacer() }
            Menu {
                Picker("收藏排序", selection: $sort) {
                    ForEach(CollectionSort.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Label(sort.rawValue, systemImage: "arrow.up.arrow.down").font(.caption).frame(minHeight: 44)
            }
        }
        .foregroundStyle(Palette.accent)
    }

    private var adaptiveControls: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func portraitCard(_ person: Companion, height: CGFloat, featured: Bool = false) -> some View {
        let count = app.hookupCount(for: person.id)
        let tier = CompanionLegendTier.resolve(hookupCount: count)
        return ZStack(alignment: .bottomLeading) {
            CollectionPortrait(companion: person, height: height)
            LinearGradient(colors: [.clear, .black.opacity(0.16), .black.opacity(0.87)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                if featured { Label(person.isPinned ? "今日回味 · 偏爱" : "今日回味", systemImage: "heart.fill").font(.caption).foregroundStyle(Palette.gold) }
                MaskedName(name: person.displayName, revealed: app.namesRevealed,
                           font: .system(featured ? .title : .title2, design: .serif))
                HStack(spacing: 8) {
                    Label(tier.label, systemImage: tier.symbolName).foregroundStyle(Palette.gold)
                    Spacer(minLength: 0)
                    Text("\(count) 次").monospacedDigit()
                }
                .font(.caption)
                if featured {
                    Text("最近相处 · \(Format.relativeDay(app.lastContact(for: person)))")
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                }
            }
            .foregroundStyle(.white).padding(featured ? 24 : 18)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: featured ? 26 : 20))
        .overlay { RoundedRectangle(cornerRadius: featured ? 26 : 20).strokeBorder(Palette.gold.opacity(0.24), lineWidth: 0.6) }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开人物档案与私藏")
    }

    private var emptyCollection: some View {
        VStack(alignment: .leading, spacing: 22) {
            AstraMark(color: Palette.gold)
            Text("第一席，留给她。")
                .font(.system(.title, design: .serif)).foregroundStyle(.white)
            Text("先建立她的档案，记下第一次亲密。封面、私藏与属于你们的战绩，都会在这里积累。")
                .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button { flow.begin(kind: .intimacy, app: app) } label: {
                PrimaryActionLabel(title: "开始第一份收藏", systemImage: "plus", onDark: true)
            }
            .buttonStyle(HapticButtonStyle())
            .accessibilityIdentifier("first-record")
        }
        .padding(26).background(Palette.velvetGradient, in: RoundedRectangle(cornerRadius: 26))
    }
}

struct CollectionPortrait: View {
    let companion: Companion
    let height: CGFloat
    @Environment(AppState.self) private var app
    @State private var photo: UIImage?
    private var photoID: String? {
        companion.photoID ?? companion.profilePhotoIDs.first ?? app.albumIDs(for: companion.id).first
    }

    var body: some View {
        Rectangle().fill(Palette.dossierGradient(companion.paletteIndex))
            .frame(height: height)
            .overlay {
                if let photo { Image(uiImage: photo).resizable().scaledToFill() }
                else {
                    ZStack {
                        Ellipse().stroke(Palette.gold.opacity(0.18), lineWidth: 1)
                            .frame(width: height * 0.48, height: height * 0.8).rotationEffect(.degrees(28))
                        Text(companion.initial).font(.system(size: height * 0.24, weight: .ultraLight, design: .serif))
                            .foregroundStyle(Palette.gold.opacity(0.42))
                    }
                }
            }
            .clipped().blur(radius: app.namesRevealed ? 0 : 24)
            .overlay { if !app.namesRevealed { Color.black.opacity(0.25) } }
            .accessibilityHidden(true)
            .task(id: photoID) { photo = photoID.flatMap { MediaStore.image(id: $0) } }
    }
}
