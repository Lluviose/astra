import SwiftUI

/// 代号打码显示。开启「默认隐藏代号」后，未揭示状态下做模糊处理。
struct MaskedName: View {
    let name: String
    let revealed: Bool
    var font: Font = .body.weight(.semibold)

    var body: some View {
        Text(revealed ? name : "••••")
            .font(font)
            .lineLimit(1)
            .privacySensitive()
            .accessibilityLabel(revealed ? name : "代号已隐藏")
    }
}

/// 对象页 / 城市面板通用的一行
struct CompanionRow: View {

    let companion: Companion
    var showCity: Bool = true

    @Environment(AppState.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isOverdue: Bool { app.isOverdue(companion) }
    private var intimateEncounters: [Encounter] {
        app.encounters(for: companion.id).filter { $0.kind.isIntimate }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AvatarView(companion: companion, size: 52, showRing: false)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    MaskedName(name: companion.displayName, revealed: app.namesRevealed)
                    if companion.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2).foregroundStyle(Palette.accent)
                            .accessibilityLabel("已置顶")
                    }
                    if isOverdue {
                        Image(systemName: "bell.badge")
                            .font(.caption2).foregroundStyle(Palette.warning)
                            .accessibilityLabel("到了联系周期")
                    }
                    if let days = companion.daysUntilBirthday, days <= 14 {
                        Image(systemName: "birthday.cake")
                            .font(.caption2).foregroundStyle(Palette.accent)
                            .accessibilityLabel(Format.birthdayCountdown(days: days))
                    }
                    Spacer(minLength: 0)
                }
                FlowLayout(spacing: 8, lineSpacing: 5) {
                    Text(companion.stage.label).foregroundStyle(companion.stage.tint)
                    if showCity { Text(app.locationName(for: companion)).foregroundStyle(Palette.secondaryInk) }
                    if companion.isArchived { Text("已归档").foregroundStyle(Palette.secondaryInk) }
                }
                .font(.caption)
                Text(intimacySummary)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var intimacySummary: String {
        let all = app.encounters(for: companion.id)
        guard let latest = all.first else { return "还没有相处记录" }
        return "\(all.count) 篇记录 · \(Format.relativeDay(latest.date))"
    }

}
