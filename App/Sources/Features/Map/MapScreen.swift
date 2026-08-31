import MapKit
import SwiftUI

/// 城市气泡：玻璃胶囊 + 指向锚点的针脚。
/// 尺寸随该城市人数变化，主色取这座城里关系最"进"的一档。
struct CityBubble: View {

    let bucket: CityBucket
    let isSelected: Bool
    let showGlow: Bool
    let action: () -> Void

    private var tint: Color { bucket.dominantStage.tint }

    /// 0.92 ~ 1.24
    private var scale: CGFloat { 0.92 + CGFloat(min(bucket.ratio, 1)) * 0.32 }

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
        .accessibilityLabel("\(bucket.city.name)，\(bucket.count) 个对象")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private var capsule: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5) }

            Text(bucket.city.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Text("\(bucket.count)")
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

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
                .ignoresSafeArea()

            header
                .frame(maxHeight: .infinity, alignment: .top)

            controlColumn
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .padding(.bottom, 8)

            if app.buckets.isEmpty {
                emptyCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 120)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.buckets.count)
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
            ForEach(app.buckets) { bucket in
                Annotation("", coordinate: bucket.city.displayCoordinate, anchor: .bottom) {
                    CityBubble(
                        bucket: bucket,
                        isSelected: selectedCityID == bucket.id,
                        showGlow: app.settings.showHeatGlow
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
        GlassStack(spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("城市足迹")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(summaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.9))
                .accessibilityLabel("关闭城市足迹")

                Button {
                    isJumpingToCity = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(HapticButtonStyle(cue: .lightTap, scale: 0.9))
                .accessibilityLabel("搜索城市")
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.vertical, 9)
            .glassCapsule(interactive: false, shadowRadius: 14)
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
    }

    private var summaryText: String {
        if app.buckets.isEmpty { return "还没有记录" }
        let cities = app.buckets.count
        let people = app.buckets.reduce(0) { $0 + $1.count }
        return "\(cities) 座城市 · \(people) 个对象"
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
            Text("还没有城市足迹")
                .font(.headline)
            Text("添加对象并选择常驻或常见面的城市，\n这里就会亮起第一颗点。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Haptics.shared.play(.mediumTap)
                isPickingCity = true
            } label: {
                Label("添加第一个对象", systemImage: "plus")
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
