import SwiftUI

/// 代号打码显示。开启「默认隐藏代号」后，未揭示状态下做模糊处理。
struct MaskedName: View {
    let name: String
    let revealed: Bool
    var font: Font = .body.weight(.semibold)

    var body: some View {
        Text(name)
            .font(font)
            .lineLimit(1)
            .blur(radius: revealed ? 0 : 5)
            .animation(.easeInOut(duration: 0.2), value: revealed)
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
            AvatarView(companion: companion, size: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    MaskedName(name: companion.displayName, revealed: app.namesRevealed)

                    if companion.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(red: 0.98, green: 0.66, blue: 0.28))
                    }
                    if isOverdue {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.warning)
                            .accessibilityLabel("到了联系周期")
                    }
                    if intimateEncounters.count >= 3 {
                        Text("回头客")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.coral)
                    }
                    if let daysToBirthday = companion.daysUntilBirthday, daysToBirthday <= 14 {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.accent)
                            .accessibilityLabel(Format.birthdayCountdown(days: daysToBirthday))
                    }
                    if companion.isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                FlowLayout(spacing: 6, lineSpacing: 6) {
                    StageBadge(stage: companion.stage)
                    if showCity {
                        Label(app.locationName(for: companion), systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
                if typeSize.isAccessibilitySize {
                    scoreSummary
                }
            }

            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 6)
                scoreSummary
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var scoreSummary: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 6) {
            CompanionScoreBadge(score: companion.overallScore, compact: true)
            Text(intimacySummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var intimacySummary: String {
        let all = app.encounters(for: companion.id)
        let missed = all.filter { $0.kind.isMissed }.count
        guard let latest = all.first else { return "还没记录" }
        var parts: [String] = []
        if !intimateEncounters.isEmpty { parts.append("上床 \(intimateEncounters.count)") }
        if missed > 0 { parts.append("没上 \(missed)") }
        parts.append(Format.relativeDay(latest.date))
        return parts.joined(separator: " · ")
    }
}

