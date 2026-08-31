import Foundation

extension DateFormatter {
    /// 「2026年8月」
    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    /// 「8月31日」
    static let dayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    /// 「2026年8月31日」
    static let dayFull: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        return formatter
    }()
}

enum Format {

    /// 今天 / 昨天 / 3 天前 / 8月12日 / 2025年8月12日
    static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        if days > 0, days < 7 { return "\(days) 天前" }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return DateFormatter.dayShort.string(from: date)
        }
        return DateFormatter.dayFull.string(from: date)
    }

    /// 「12 天没联系」用的短文案
    static func silence(days: Int) -> String {
        switch days {
        case 0: "今天联系过"
        case 1: "昨天联系过"
        default: "\(days) 天没联系"
        }
    }

    /// ¥1,280
    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "CNY").precision(.fractionLength(0)))
    }

    /// 生日倒计时
    static func birthdayCountdown(days: Int) -> String {
        switch days {
        case 0: "今天生日"
        case 1: "明天生日"
        default: "\(days) 天后生日"
        }
    }

    /// 待跟进日期：今天 / 明天 / 已超期 2 天 / 5 天后 / 9月18日
    static func followUpDue(_ date: Date?) -> String {
        guard let date else { return "未设日期" }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        switch days {
        case 0: return "今天"
        case 1: return "明天"
        case ..<0: return "已超期 \(-days) 天"
        case 2...7: return "\(days) 天后"
        default: return DateFormatter.dayShort.string(from: target)
        }
    }

    static func height(_ cm: Int?) -> String? {
        guard let cm else { return nil }
        return "\(cm) cm"
    }

    static func age(_ age: Int?) -> String? {
        guard let age else { return nil }
        return "\(age) 岁"
    }
}
