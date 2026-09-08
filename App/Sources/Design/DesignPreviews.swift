#if DEBUG
import SwiftUI

/// Interactive component previews use fixture text only and never open a user's store.
private struct DesignShowcase: View {
    @State private var selected = true
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AstraLayout.sectionSpacing) {
                HStack {
                    Text("你的私人星图").font(.largeTitle.bold())
                    Spacer()
                    AstraMark().foregroundStyle(Palette.accent)
                }
                HeroPanel {
                    VStack(alignment: .leading, spacing: 20) {
                        HeroBadge(title: "只在这台手机上")
                        Text("每一页，都属于你")
                            .font(.title.weight(.semibold))
                        HStack {
                            HeroMetric(value: "12", label: "记录")
                            HeroMetric(value: "3", label: "地点")
                        }
                        HeroButton(title: "记一笔", systemImage: "plus", prominent: true) {
                            selected.toggle()
                        }
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                         count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                    EntryTile(title: "成就册", subtitle: "每一点进步，都有回响", systemImage: "medal", tint: Palette.goldDeep)
                    EntryTile(title: "版图", subtitle: "收藏走过的地方", systemImage: "map", tint: Palette.safe)
                }
                SectionCard("最近记录", systemImage: "clock", trailing: { Text("今天") }) {
                    Text("清晰的内容，安静的留白。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    FlowLayout {
                        GlassChip(title: "已选择", systemImage: "bookmark", isOn: selected) { selected.toggle() }
                        GlassChip(title: "全部记录", systemImage: "square.stack", isOn: !selected) { selected.toggle() }
                    }
                }
                HStack(spacing: 16) {
                    GlassIconButton(systemImage: "map", isActive: selected, accessibilityText: "切换地图") { selected.toggle() }
                    GlassIconButton(systemImage: "plus", accessibilityText: "新增记录") { selected.toggle() }
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

#Preview("大字体 · 减少透明度与动态效果") {
    DesignShowcase()
        .dynamicTypeSize(.accessibility3)
        .environment(\.accessibilityReduceTransparency, true)
        .environment(\.accessibilityReduceMotion, true)
        .environment(\.colorSchemeContrast, .increased)
}
#endif
