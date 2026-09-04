#if DEBUG
import Foundation

/// Deterministic, fictional UI review data in a dedicated defaults suite.
/// Never loaded in Release or used to replace the user's standard store.
@MainActor
enum UIReviewFixtures {
    static func makeStateIfRequested() -> AppState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing"),
              let defaults = UserDefaults(suiteName: "com.lluviose.astra.ui-review") else { return nil }
        defaults.removePersistentDomain(forName: "com.lluviose.astra.ui-review")
        let store = LocalStore(defaults: defaults)
        var settings = AppSettings.default
        settings.appearance = arguments.contains("--ui-dark") ? .dark : .light
        settings.maskNamesByDefault = false
        settings.hapticsEnabled = false
        settings.appLockEnabled = false
        store.save(settings, for: .settings)
        var people: [Companion] = []
        var records: [Encounter] = []
        if !arguments.contains("--ui-empty") {
            people = [
                Companion(name: "林间", paletteIndex: 2, cityID: "310000", stage: .regular, tags: ["咖啡", "散步"], isPinned: true),
                Companion(name: "海盐", paletteIndex: 1, cityID: "330100", stage: .flirting, tags: ["展览"]),
                Companion(name: "南风", paletteIndex: 0, cityID: "110000", stage: .chatting),
            ]
            for index in 0..<8 {
                let person = people[index % people.count]
                records.append(Encounter(
                    companionID: person.id,
                    date: Calendar.current.date(byAdding: .day, value: -index * 3, to: Date())!,
                    kind: index % 3 == 2 ? .missed : .intimacy,
                    cityID: person.cityID,
                    place: index % 2 == 0 ? "沿河散步" : "周末的午后",
                    protectionStatus: index % 3 == 2 ? .notRecorded : .protected,
                    note: index == 0 ? "一起走过很长的路，聊到天色暗下来。" : "把这个片刻留在这里。"
                ))
            }
        }
        store.save(people, for: .companions)
        store.save(records, for: .encounters)
        return AppState(store: store, performsMediaMaintenance: false)
    }
}
#endif
