import MapKit
import SwiftUI

private enum MapRecordScope: String, CaseIterable, Identifiable {
    case all
    case hookedUp
    case missed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "全部"
        case .hookedUp: "战绩"
        case .missed: "没上"
        }
    }

    func count(in bucket: CityBucket) -> Int {
        switch self {
        case .all: bucket.mapCount
        case .hookedUp: bucket.hookupCount
        case .missed: bucket.missedCount
        }
    }

    func tint(for bucket: CityBucket) -> Color {
        switch self {
        case .all: bucket.mapTint
        case .hookedUp: EncounterKind.intimacy.tint
        case .missed: EncounterKind.missed.tint
        }
    }
}

/// 城市气泡：玻璃胶囊 + 指向锚点的针脚。
/// 尺寸随该城市记录数变化，主色由当前结果图层决定。
private struct CityBubble: View {

    let bucket: CityBucket
    let scope: MapRecordScope
    let isSelected: Bool
    let showGlow: Bool
    let maxDisplayCount: Int
    let action: () -> Void

    private var tint: Color { scope.tint(for: bucket) }
    private var displayCount: Int { scope.count(in: bucket) }
    private var symbolName: String {
        switch scope {
        case .hookedUp: return "flame.fill"
        case .missed: return "xmark"
        case .all:
            if bucket.hookupCount > 0 { return "flame.fill" }
            if bucket.missedCount > 0 { return "xmark" }
            return "mappin"
        }
    }

    /// 0.92 ~ 1.24；每个图层按自己的最高战绩缩放，没上记录不会放大上床气泡。
    private var scale: CGFloat {
        let ratio = Double(displayCount) / Double(max(maxDisplayCount, 1))
        return 0.92 + CGFloat(min(ratio, 1)) * 0.32
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                capsule
                stem
            }
            .background(alignment: .top) { glow }
            .scaleEffect(isSelected ? scale * 1.10 : scale, anchor: .bottom)
            .animation(.spring(response: 0.34, dampingFraction: 0.68), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel("\(bucket.city.name)，\(scope.label) \(displayCount)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private var capsule: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)

            Text(bucket.city.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text("\(displayCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white : tint)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.18)))
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassCapsule(tint: isSelected ? tint.opacity(0.35) : nil, interactive: true, shadowRadius: 10)
    }

    /// 针脚：一小段竖线 + 落点圆点
    private var stem: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(tint.opacity(0.85))
                .frame(width: 2, height: 9)
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .overlay { Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1) }
                .shadow(color: tint.opacity(0.5), radius: 3)
        }
    }

    @ViewBuilder
    private var glow: some View {
        if showGlow {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.42), tint.opacity(0.0)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 46
                    )
                )
                .frame(width: 92, height: 92)
                .blur(radius: 6)
                .offset(y: -8)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - 地图主界面

struct MapScreen: View {

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition = .region(ChinaRegion.overview)
    @State private var selectedCityID: String?
    @State private var editorTarget: Companion?
    @State private var pendingEditorTarget: Companion?
    @State private var isPickingCity = false
    @State private var isJumpingToCity = false
    /// 地图默认就是巡视已经拿下的版图，而不是把待推进对象和战绩混在一起。
    @State private var scope: MapRecordScope = .hookedUp

    private var filteredBuckets: [CityBucket] {
        switch scope {
        case .all:
            app.buckets
        case .hookedUp:
            app.conquestBuckets
        case .missed:
            app.buckets.filter { $0.missedCount > 0 }
        }
    }

    private var conquestRoute: [CLLocationCoordinate2D] {
        app.conquestCityPath().map(\.displayCoordinate)
    }

    private var maxDisplayCount: Int {
        max(1, filteredBuckets.map { scope.count(in: $0) }.max() ?? 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
                .ignoresSafeArea()

            if app.buckets.isEmpty {
                emptyCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 120)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if filteredBuckets.isEmpty {
                scopeEmptyCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 120)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .overlay(alignment: .bottomTrailing) {
            controlColumn
                .padding(.trailing, 16)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomLeading) {
            if scope != .missed,
               let top = app.topConquestBucket,
               !filteredBuckets.isEmpty {
                topCityBadge(top)
                    .padding(.leading, 16)
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.buckets.count)
        .animation(.easeInOut(duration: 0.25), value: scope)
        .onChange(of: scope) { _, _ in selectedCityID = nil }
        .sheet(item: selectedBucketBinding, onDismiss: presentPendingEditor) { bucket in
            CityDetailSheet(bucket: bucket) { companion in
                pendingEditorTarget = companion
            }
        }
        .sheet(item: $editorTarget) { companion in
            CompanionEditor(companion: companion)
        }
        .sheet(isPresented: $isPickingCity, onDismiss: presentPendingEditor) {
            CityPickerSheet(title: "常驻或常见面的城市") { city in
                var draft = app.makeDraftCompanion(cityID: city.id)
                draft.cityID = city.id
                pendingEditorTarget = draft
            }
        }
        .sheet(isPresented: $isJumpingToCity) {
            CityPickerSheet(title: "跳到城市", subtitle: "只显示中国境内的城市") { city in
                focus(on: city, select: app.buckets.contains { $0.id == city.id })
            }
        }
    }

    // MARK: 地图层

    private var mapLayer: some View {
        Map(
            position: $camera,
            bounds: ChinaRegion.cameraBounds,
            interactionModes: [.pan, .zoom]
        ) {
            if scope != .missed, conquestRoute.count >= 2 {
                MapPolyline(coordinates: conquestRoute)
                    .stroke(
                        Palette.coral.opacity(scope == .hookedUp ? 0.86 : 0.56),
                        style: StrokeStyle(
                            lineWidth: scope == .hookedUp ? 3.4 : 2.4,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [9, 6]
                        )
                    )
            }

            ForEach(filteredBuckets) { bucket in
                Annotation("", coordinate: bucket.city.displayCoordinate, anchor: .bottom) {
                    CityBubble(
                        bucket: bucket,
                        scope: scope,
                        isSelected: selectedCityID == bucket.id,
                        showGlow: app.settings.showHeatGlow,
                        maxDisplayCount: maxDisplayCount
                    ) {
                        select(bucket)
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(resolvedMapStyle)
    }

    /// MapStyle 是具体类型，避免 AnyView 在拖动时拆掉 Map 身份导致卡顿。
    private var resolvedMapStyle: MapStyle {
        switch app.settings.mapSkin {
        case .muted:
            .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll)
        case .standard:
            .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .satellite:
            .imagery(elevation: .flat)
        }
    }

    // MARK: 顶部信息条

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.9))
                .accessibilityLabel("关闭猎场地图")

                VStack(alignment: .leading, spacing: 1) {
                    Text("王者版图")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(summaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button {
                    isJumpingToCity = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.9))
                .accessibilityLabel("搜索城市")
            }

            Picker("地图结果", selection: $scope) {
                ForEach(MapRecordScope.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if scope != .missed, conquestRoute.count >= 2 {
                HStack(spacing: 6) {
                    Label("战绩路线 \(conquestRoute.count) 城", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    Spacer()
                    if let top = app.topConquestBucket {
                        Text("头号猎场 · \(top.city.name)")
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 22, interactive: true, shadowRadius: 14)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var summaryText: String {
        if app.buckets.isEmpty { return "还没有记录" }
        switch scope {
        case .hookedUp:
            return "\(app.conqueredCompanions.count) 个她 · 上床 \(app.stats.totalIntimacyCount) 次 · \(app.conquestCityCount) 城版图"
        case .all:
            return "\(app.buckets.count) 城有故事 · 战绩 \(app.conquestCityCount) 城 · 共 \(app.encounters.count) 条"
        case .missed:
            return "没上 \(app.stats.missedCount) 次 · 复盘后继续拓场"
        }
    }

    private func topCityBadge(_ bucket: CityBucket) -> some View {
        Button {
            select(bucket)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.80, blue: 0.28).opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.92, green: 0.63, blue: 0.12))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("头号猎场 · \(bucket.city.name)")
                        .font(.caption.weight(.bold))
                    Text("\(bucket.hookupCompanionCount) 个她 · 上床 \(bucket.hookupCount) 次")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .glassCard(cornerRadius: 18, interactive: true, shadowRadius: 10)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(HapticButtonStyle(cue: .cityFocus, scale: 0.96))
    }

    // MARK: 右下悬浮控件

    private var controlColumn: some View {
        GlassStack(spacing: 14) {
            VStack(spacing: 12) {
                GlassIconButton(
                    systemImage: "globe.asia.australia.fill",
                    accessibilityText: "回到全国"
                ) {
                    resetCamera()
                }

                GlassIconButton(
                    systemImage: app.settings.mapSkin.symbolName,
                    accessibilityText: "切换底图样式：当前\(app.settings.mapSkin.label)"
                ) {
                    cycleMapSkin()
                }

                GlassIconButton(
                    systemImage: app.settings.showHeatGlow ? "sparkles" : "sparkle",
                    tint: Palette.accent,
                    isActive: app.settings.showHeatGlow,
                    accessibilityText: "城市光晕"
                ) {
                    var updated = app.settings
                    updated.showHeatGlow.toggle()
                    app.updateSettings(updated)
                }

                GlassIconButton(
                    systemImage: "plus",
                    size: 54,
                    tint: Palette.accent,
                    isActive: true,
                    cue: .mediumTap,
                    accessibilityText: "添加对象"
                ) {
                    isPickingCity = true
                }
            }
        }
    }

    // MARK: 空态

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.7))
            Text("版图还是空的")
                .font(.headline)
            Text("真正记下一次「上床了」并选择城市，\n这里才会点亮第一块战绩版图。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Haptics.shared.play(.mediumTap)
                isPickingCity = true
            } label: {
                Label("先加一个人", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .glassActionStyle(prominent: true)
            .tint(Palette.accent)
            .padding(.top, 2)
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private var scopeEmptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: scope == .hookedUp ? "flame" : "xmark.circle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(scope == .hookedUp ? EncounterKind.intimacy.tint : EncounterKind.missed.tint)
            Text(scope == .hookedUp ? "还没有上床足迹" : "还没有没上床的城市")
                .font(.headline)
            Text(scope == .hookedUp
                ? "切回全部查看已有猎场，或去新城市留下下一次结果。"
                : "切回全部查看已有猎场；没成的记录也会保留在时间线上。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("查看全部") {
                scope = .all
            }
            .glassActionStyle(prominent: true)
            .tint(Palette.accent)
            .padding(.top, 2)
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    // MARK: 行为

    private var selectedBucketBinding: Binding<CityBucket?> {
        Binding(
            get: { app.buckets.first { $0.id == selectedCityID } },
            set: { selectedCityID = $0?.id }
        )
    }

    private func select(_ bucket: CityBucket) {
        Haptics.shared.play(.cityFocus)
        selectedCityID = bucket.id
        focus(on: bucket.city, select: false)
    }

    private func presentPendingEditor() {
        guard let pendingEditorTarget else { return }
        self.pendingEditorTarget = nil
        editorTarget = pendingEditorTarget
    }

    private func focus(on city: City, select shouldSelect: Bool) {
        if shouldSelect { selectedCityID = city.id }
        withAnimation(.easeInOut(duration: 0.65)) {
            camera = .region(ChinaRegion.focus(on: city.displayCoordinate, spanDegrees: 2.4))
        }
    }

    private func resetCamera() {
        selectedCityID = nil
        withAnimation(.easeInOut(duration: 0.7)) {
            camera = .region(ChinaRegion.overview)
        }
    }

    private func cycleMapSkin() {
        let all = MapSkin.allCases
        guard let index = all.firstIndex(of: app.settings.mapSkin) else { return }
        var updated = app.settings
        updated.mapSkin = all[(index + 1) % all.count]
        app.updateSettings(updated)
    }
}
