import SwiftUI

/// 名字打码显示。开启「默认隐藏名字」后，未揭示状态下做模糊处理。
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
            .accessibilityLabel(revealed ? name : "名字已隐藏")
    }
}

/// 名单 / 城市面板通用的一行
struct CompanionRow: View {

    let companion: Companion
    var showCity: Bool = true

    @Environment(AppState.self) private var app

    private var isOverdue: Bool { app.isOverdue(companion) }
    private var days: Int { app.daysSinceContact(for: companion) }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(companion: companion, size: 46)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    MaskedName(name: companion.displayName, revealed: app.namesRevealed)

                    if companion.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(red: 0.98, green: 0.66, blue: 0.28))
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

                HStack(spacing: 6) {
                    StageBadge(stage: companion.stage)
                    if showCity {
                        Label(app.cityName(for: companion), systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 6) {
                RatingStars(rating: companion.rating, size: 10)
                Text(Format.silence(days: days))
                    .font(.caption2)
                    .foregroundStyle(isOverdue ? Palette.accent : .secondary)
                    .fontWeight(isOverdue ? .semibold : .regular)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
