import SwiftUI

/// 后宫图鉴只陈列真正记录过「上床了」的人，和仍在推进的名册彻底分开。
struct HaremGalleryScreen: View {

    @Environment(AppState.self) private var app

    @State private var sort: HaremSort = .hookups
    @State private var viewingPhotoIDs: [String] = []
    @State private var viewingPhotoIndex: Int?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var companions: [Companion] {
        app.conqueredCompanions.sorted { lhs, rhs in
            switch sort {
            case .hookups:
                let left = app.hookupCount(for: lhs.id)
                let right = app.hookupCount(for: rhs.id)
                if left != right { return left > right }
            case .recent:
                let left = app.lastHookup(for: lhs.id)?.date ?? .distantPast
                let right = app.lastHookup(for: rhs.id)?.date ?? .distantPast
                if left != right { return left > right }
            case .score:
                if lhs.overallScore != rhs.overallScore { return lhs.overallScore > rhs.overallScore }
            case .photos:
                let left = galleryPhotoIDs(for: lhs).count
                let right = galleryPhotoIDs(for: rhs).count
                if left != right { return left > right }
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// 每天固定翻出一个不同的人，形成“今天回味谁”的重访入口。
    private var memoryCompanion: Companion? {
        let all = app.conqueredCompanions
        guard !all.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return all[day % all.count]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                royalHeader

                if let memoryCompanion {
                    memoryHero(memoryCompanion)
                    collectionControls
                    galleryGrid
                } else {
                    emptyState
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Palette.screenGradient.ignoresSafeArea())
        .navigationTitle("后宫图鉴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.toggleNamesRevealed()
                } label: {
                    Image(systemName: app.namesRevealed ? "eye.slash" : "eye")
                }
                .accessibilityLabel(app.namesRevealed ? "隐藏图鉴" : "揭开图鉴")
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewingPhotoIndex != nil },
            set: { if !$0 { viewingPhotoIndex = nil } }
        )) {
            PhotoViewer(ids: viewingPhotoIDs, index: viewingPhotoIndex ?? 0)
        }
    }

    private var royalHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("私人收藏", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
                Spacer()
                Label("王者图鉴", systemImage: "crown.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.30))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("上过的，都在这里")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("不是待办，也不是聊天列表。这里专门用来翻照片、数战绩、回味已经发生过的故事。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 9) {
                royalMetric("\(app.conqueredCompanions.count)", "女人")
                royalMetric("\(app.stats.totalIntimacyCount)", "上床")
                royalMetric("\(app.stats.repeatGirlCount)", "回头客")
                royalMetric("\(app.conquestLocationCount)", "战绩地")
            }

            HStack(spacing: 6) {
                Image(systemName: "photo.stack.fill")
                Text("私藏 \(app.privateCollectionCount) 张")
                Text("·")
                Image(systemName: "medal.fill")
                Text("成就 \(app.achievements.filter(\.isUnlocked).count)/\(app.achievements.count)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.70))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.035, blue: 0.16),
                    Color(red: 0.36, green: 0.07, blue: 0.30),
                    Color(red: 0.78, green: 0.15, blue: 0.34),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "crown.fill")
                .font(.system(size: 94, weight: .black))
                .foregroundStyle(.white.opacity(0.055))
                .offset(x: 14, y: -12)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Palette.coral.opacity(0.24), radius: 22, y: 12)
    }

    private func royalMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func memoryHero(_ companion: Companion) -> some View {
        let photos = galleryPhotoIDs(for: companion)
        let last = app.lastHookup(for: companion.id)
        return VStack(spacing: 0) {
            Button {
                openPhotos(photos)
            } label: {
                ZStack(alignment: .bottomLeading) {
                    HaremPortrait(
                        companion: companion,
                        photoID: coverPhotoID(for: companion),
                        height: 286,
                        cornerRadius: 26
                    )

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.12), .black.opacity(0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Label("今日回味", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.30))
                        MaskedName(
                            name: companion.displayName,
                            revealed: app.namesRevealed,
                            font: .title2.weight(.bold)
                        )
                        HStack(spacing: 8) {
                            Label("上床 \(app.hookupCount(for: companion.id))", systemImage: "flame.fill")
                            if !photos.isEmpty {
                                Label("\(photos.count) 张", systemImage: "photo.fill")
                            }
                            if let last {
                                Text("· \(Format.relativeDay(last.date))")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                }
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.985))
            .disabled(photos.isEmpty)

            NavigationLink(value: companion.id) {
                HStack {
                    Text(photos.isEmpty ? "打开档案，给她补上照片" : "点照片直接翻阅 · 打开档案看完整故事")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .glassCard(cornerRadius: 26, shadowRadius: 12)
    }

    private var collectionControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("全部收藏")
                    .font(.headline)
                Text("\(companions.count) 个她，只陈列已经上过的")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Picker("图鉴排序", selection: $sort) {
                    ForEach(HaremSort.allCases) { item in
                        Label(item.label, systemImage: item.symbolName).tag(item)
                    }
                }
            } label: {
                Label(sort.label, systemImage: sort.symbolName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassCapsule(interactive: true, shadowRadius: 5)
            }
        }
    }

    private var galleryGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(companions.enumerated()), id: \.element.id) { index, companion in
                HaremCard(
                    companion: companion,
                    rank: index + 1,
                    coverPhotoID: coverPhotoID(for: companion),
                    photoIDs: galleryPhotoIDs(for: companion),
                    onOpenPhotos: { openPhotos($0) }
                )
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: "crown",
            title: "图鉴还没开张",
            message: "名册里的人不会自动算进来。真正记下一次「上床了」，她才会出现在你的私人后宫图鉴。"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 24, shadowRadius: 10)
    }

    private func coverPhotoID(for companion: Companion) -> String? {
        app.profilePhotoIDs(for: companion.id).first
            ?? app.albumIDs(for: companion.id).first
    }

    private func galleryPhotoIDs(for companion: Companion) -> [String] {
        var seen = Set<String>()
        return (app.profilePhotoIDs(for: companion.id) + app.albumIDs(for: companion.id)).filter {
            seen.insert($0).inserted
        }
    }

    private func openPhotos(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        guard app.namesRevealed else {
            Haptics.shared.play(.warning)
            return
        }
        Haptics.shared.play(.cityFocus)
        viewingPhotoIDs = ids
        viewingPhotoIndex = 0
    }
}

private enum HaremSort: String, CaseIterable, Identifiable {
    case hookups
    case recent
    case score
    case photos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hookups: "上床最多"
        case .recent: "最近上过"
        case .score: "综合最高"
        case .photos: "照片最多"
        }
    }

    var symbolName: String {
        switch self {
        case .hookups: "flame.fill"
        case .recent: "clock.fill"
        case .score: "crown.fill"
        case .photos: "photo.stack.fill"
        }
    }
}

private struct HaremCard: View {
    let companion: Companion
    let rank: Int
    let coverPhotoID: String?
    let photoIDs: [String]
    let onOpenPhotos: ([String]) -> Void

    @Environment(AppState.self) private var app

    private var lastHookup: Encounter? { app.lastHookup(for: companion.id) }

    private var cityName: String {
        if let cityID = lastHookup?.cityID, let city = app.city(id: cityID) {
            return city.name
        }
        return app.cityName(for: companion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onOpenPhotos(photoIDs)
            } label: {
                ZStack(alignment: .topLeading) {
                    HaremPortrait(
                        companion: companion,
                        photoID: coverPhotoID,
                        height: 188,
                        cornerRadius: 20
                    )

                    Text(rank <= 3 ? "#\(rank)" : "\(rank)")
                        .font(.caption2.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(rank <= 3 ? Color.black.opacity(0.78) : Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            rank <= 3
                                ? AnyShapeStyle(Color(red: 1.0, green: 0.80, blue: 0.28).gradient)
                                : AnyShapeStyle(Color.black.opacity(0.48)),
                            in: Capsule()
                        )
                        .padding(10)

                    if !photoIDs.isEmpty {
                        Label("\(photoIDs.count)", systemImage: "photo.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.48), in: Capsule())
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(photoIDs.isEmpty)

            NavigationLink(value: companion.id) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        MaskedName(
                            name: companion.displayName,
                            revealed: app.namesRevealed,
                            font: .subheadline.weight(.bold)
                        )
                        Spacer(minLength: 2)
                        if companion.overallScore > 0 {
                            Label("\(companion.overallScore)", systemImage: "crown.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.warning)
                        }
                    }

                    HStack(spacing: 5) {
                        Label("\(app.hookupCount(for: companion.id))", systemImage: "flame.fill")
                            .foregroundStyle(Palette.coral)
                        Text("·")
                        Text(cityName)
                        if let date = lastHookup?.date {
                            Text("· \(Format.relativeDay(date))")
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .glassCard(cornerRadius: 20, shadowRadius: 9)
        .opacity(companion.isArchived ? 0.72 : 1)
    }
}

/// 图鉴与首页共用的大幅人物封面。隐私未揭开时，真实照片始终模糊。
struct HaremPortrait: View {
    let companion: Companion
    let photoID: String?
    var height: CGFloat
    var cornerRadius: CGFloat = 22

    @Environment(AppState.self) private var app
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(Palette.avatarGradient(companion.paletteIndex))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: height)
                        .clipped()
                        .blur(radius: app.namesRevealed ? 0 : 18)
                } else {
                    Text(companion.initial)
                        .font(.system(size: min(proxy.size.width, height) * 0.32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.90))
                }

                LinearGradient(
                    colors: [.white.opacity(0.20), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )

                if !app.namesRevealed, image != nil {
                    Label("已隐藏", systemImage: "eye.slash.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.34), in: Capsule())
                }
            }
            .frame(width: proxy.size.width, height: height)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
        }
        .task(id: photoID) {
            image = photoID.flatMap { MediaStore.image(id: $0) }
        }
        .accessibilityElement()
        .accessibilityLabel(app.namesRevealed ? companion.displayName : "人物照片已隐藏")
    }
}
