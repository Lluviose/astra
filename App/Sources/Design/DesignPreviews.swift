#if DEBUG
import SwiftUI

/// Interactive component previews use fixture text only and never open a user's store.
private struct DesignShowcase: View {
    @State private var selected = true
    @State private var scope = "all"
    @State private var meter = 0.62
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AstraLayout.sectionSpacing) {
                HStack {
                    Text("你的私人星图").font(.largeTitle.bold())
                    Spacer()
                    AstraMark().foregroundStyle(Palette.accent)
                }
                HeroPanel(animated: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        HeroBadge(title: "只在这台手机上")
                        Text("每一页，都属于你")
                            .font(.title.weight(.semibold))
                        MeterBar(value: meter, tint: Palette.gold, height: 5, onDark: true)
                        HStack {
                            HeroMetric(value: "12", label: "记录")
                            HeroMetric(value: "3", label: "地点")
                        }
                        HeroButton(title: "记一笔", systemImage: "plus", prominent: true) {
                            meter = meter > 0.9 ? 0.2 : meter + 0.2
                        }
                    }
                }
                PillPicker(
                    options: [
                        PillOption(value: "all", title: "全部", systemImage: "square.stack"),
                        PillOption(value: "hookup", title: "上床", systemImage: "flame.fill"),
                        PillOption(value: "missed", title: "没上", systemImage: "xmark.circle"),
                        PillOption(value: "follow", title: "跟进", systemImage: "checklist"),
                    ],
                    selection: $scope,
                    scrollable: false,
                    fillsWidth: true
                )
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                         count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                    EntryTile(title: "成就册", subtitle: "每一点进步，都有回响", systemImage: "medal", tint: Palette.goldDeep)
                    EntryTile(title: "版图", subtitle: "收藏走过的地方", systemImage: "map", tint: Palette.safe)
                }
                SectionCard("最近记录", systemImage: "clock", trailing: { Text("今天") }) {
                    Text("清晰的内容，安静的留白。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    MeterBar(value: meter, tint: Palette.coral)
                    FlowLayout {
                        GlassChip(title: "已选择", systemImage: "bookmark", isOn: selected) { selected.toggle() }
                        GlassChip(title: "全部记录", systemImage: "square.stack", isOn: !selected) { selected.toggle() }
                    }
                    HStack(spacing: 10) {
                        SurfaceButtonLabel(title: "打开档案", systemImage: "book.pages.fill")
                        SurfaceButtonLabel(title: "记录结果", systemImage: "plus.circle.fill", prominent: true)
                    }
                }
                HStack(spacing: 16) {
                    Medallion(systemImage: "flame.fill", tint: Palette.coral, ring: Palette.gold, size: 52)
                    Medallion(systemImage: "map.fill", tint: Palette.safe, ring: Palette.gold, size: 52, isLit: false)
                    GlassIconButton(systemImage: "map", isActive: selected, accessibilityText: "切换地图") { selected.toggle() }
                    SymbolTile(systemImage: "lock.shield", tint: Palette.safe)
                    SymbolTile(systemImage: "heart", tint: Palette.coral)
                }
            }
            .padding(AstraLayout.pageInset)
            .frame(maxWidth: AstraLayout.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .tint(Palette.accent)
    }
}

#Preview("浅色 · 内容与控件") {
    DesignShowcase().preferredColorScheme(.light)
}

#Preview("深色 · 内容与控件") {
    DesignShowcase().preferredColorScheme(.dark)
}

// Reduce Motion, Reduce Transparency and Increase Contrast are read-only environment
// values. Toggle them in Simulator Settings when reviewing the running app.
#Preview("大字体") {
    DesignShowcase()
        .dynamicTypeSize(.accessibility3)
}
#endif
