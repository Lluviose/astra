import Foundation
import UserNotifications

/// 经期本机通知。锁屏文案故意写得很短，默认隐藏代号时连代号也不出现。
enum PeriodNotificationScheduler {

    static let identifierPrefix = "astra.period."

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func reschedule(
        companions: [Companion],
        records: [PeriodRecord],
        settings: AppSettings
    ) {
        guard !isRunningTests else { return }
        Task { await rescheduleAsync(companions: companions, records: records, settings: settings) }
    }

    static func clearAll() {
        guard !isRunningTests else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func rescheduleAsync(
        companions: [Companion],
        records: [PeriodRecord],
        settings: AppSettings
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        guard settings.periodNotificationsEnabled else { return }
        let authorization = await center.notificationSettings()
        switch authorization.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let grouped = Dictionary(grouping: records, by: \.companionID)
        let now = Date()
        var requests: [UNNotificationRequest] = []
        for companion in companions {
            guard companion.periodTrackingEnabled,
                  companion.periodNotifyEnabled,
                  !companion.isArchived,
                  companion.stage.isActive
            else { continue }
            let forecast = CycleEngine.forecast(
                records: grouped[companion.id] ?? [],
                typicalCycleDays: companion.typicalCycleDays,
                typicalPeriodDays: companion.typicalPeriodDays,
                asOf: now
            )
            requests.append(contentsOf: makeRequests(
                companion: companion,
                forecast: forecast,
                maskNames: settings.maskNamesByDefault,
                now: now
            ))
        }

        for request in requests.prefix(48) {
            try? await center.add(request)
        }
    }

    private static func makeRequests(
        companion: Companion,
        forecast: CycleForecast,
        maskNames: Bool,
        now: Date
    ) -> [UNNotificationRequest] {
        guard let next = forecast.nextStart else { return [] }
        let calendar = Calendar.current
        var dates: [(kind: String, date: Date, title: String, body: String)] = []
        let name = maskNames ? nil : companion.displayName
        let lead = companion.periodNotifyLeadDays

        func add(_ kind: String, on day: Date, title: String, body: String) {
            let fire = fireDate(on: day, calendar: calendar)
            guard fire > now else { return }
            dates.append((kind, fire, title, body))
        }

        let starts = [next, calendar.date(byAdding: .day, value: forecast.cycleDays, to: next)].compactMap { $0 }
        for start in starts {
            let shift = calendar.dateComponents([.day], from: next, to: start).day ?? 0
            if let leadDay = calendar.date(byAdding: .day, value: -lead, to: start) {
                add(
                    "lead",
                    on: leadDay,
                    title: "星图",
                    body: name.map { "\($0) 的经期大概 \(lead == 1 ? "明天" : "\(lead) 天后")开始。" }
                        ?? "有一份经期提醒，打开查看。"
                )
            }
            add(
                "start",
                on: start,
                title: "星图",
                body: name.map { "\($0) 的经期大概从今天开始。" } ?? "有一份经期可能开始的提醒。"
            )
            if let lateDay = calendar.date(byAdding: .day, value: forecast.windowRadius + 1, to: start) {
                add(
                    "late",
                    on: lateDay,
                    title: "星图",
                    body: name.map { "\($0) 的经期可能推迟了，记下实际来的那天会让下次更准。" }
                        ?? "有一份周期提醒还没记下。"
                )
            }
            guard companion.periodNotifyFertile else { continue }
            if let fertile = forecast.fertileStart,
               let shiftedFertile = calendar.date(byAdding: .day, value: shift, to: fertile) {
                add(
                    "fertile",
                    on: shiftedFertile,
                    title: "星图",
                    body: name.map { "\($0) 的易孕窗口大概从今天开始。" } ?? "有一份周期窗口提醒。"
                )
            }
            if let ovulation = forecast.ovulation,
               let shiftedOvulation = calendar.date(byAdding: .day, value: shift, to: ovulation) {
                add(
                    "ovulation",
                    on: shiftedOvulation,
                    title: "星图",
                    body: name.map { "\($0) 今天可能排卵。" } ?? "有一份周期窗口提醒。"
                )
            }
        }

        return dates.map { item in
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = "astra.period"
            content.userInfo = ["companionID": companion.id.uuidString, "kind": item.kind]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let dayStamp = Self.dayStamp(item.date, calendar: calendar)
            return UNNotificationRequest(
                identifier: "\(identifierPrefix)\(companion.id.uuidString).\(item.kind).\(dayStamp)",
                content: content,
                trigger: trigger
            )
        }
    }

    private static func fireDate(on day: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: day))
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? day
    }

    private static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
