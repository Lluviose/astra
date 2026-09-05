import Foundation

enum RecordPeriod: String, CaseIterable, Identifiable {
    case all, month, quarter, year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "全部时间"
        case .month: "本月"
        case .quarter: "近 90 天"
        case .year: "今年"
        }
    }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all: return true
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return false }
            return date >= interval.start && date < interval.end
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return false }
            return date >= interval.start && date < interval.end
        case .quarter:
            let today = calendar.startOfDay(for: now)
            guard let start = calendar.date(byAdding: .day, value: -89, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: today) else { return false }
            return date >= start && date < end
        }
    }
}

enum JournalScope: String, CaseIterable, Identifiable {
    case all, intimate, other, pending
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "全部"
        case .intimate: "亲密"
        case .other: "未亲密"
        case .pending: "待跟进"
        }
    }
}

/// Search, person, date and outcome are intersected so every visible filter is reliable.
struct JournalFilter: Equatable {
    var query = ""
    var period: RecordPeriod = .all
    var scope: JournalScope = .all
    var companionID: UUID?

    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || period != .all || scope != .all || companionID != nil
    }

    func apply(to encounters: [Encounter], companions: [Companion],
               locationName: (Encounter) -> String,
               now: Date = Date(), calendar: Calendar = .current) -> [Encounter] {
        let people = companions.reduce(into: [UUID: Companion]()) { $0[$1.id] = $1 }
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return encounters.filter { record in
            guard period.contains(record.date, now: now, calendar: calendar),
                  companionID == nil || record.companionID == companionID else { return false }
            switch scope {
            case .all: break
            case .intimate: if !record.kind.isIntimate { return false }
            case .other: if !record.kind.isMissed { return false }
            case .pending: if !record.hasPendingFollowUp { return false }
            }
            guard !search.isEmpty else { return true }
            let person = people[record.companionID]
            let fields = [record.note, record.place, record.followUpNote, locationName(record),
                          person?.displayName ?? "", person?.tags.joined(separator: " ") ?? "",
                          record.activitySummary, record.climaxSummary]
            return fields.contains { $0.localizedStandardContains(search) }
        }.sorted { $0.date > $1.date }
    }
}
