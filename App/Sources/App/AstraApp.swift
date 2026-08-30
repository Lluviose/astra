import SwiftUI

@main
struct AstraApp: App {

    @State private var appState = AppState()
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(lock)
                .tint(Palette.accent)
                .preferredColorScheme(appState.settings.appearance.colorScheme)
                .onAppear {
                    lock.configure(enabled: appState.settings.appLockEnabled, lockNow: true)
                    Haptics.shared.prepare()
                }
                .onChange(of: appState.settings.appLockEnabled) { _, enabled in
                    lock.configure(enabled: enabled)
                }
                .onChange(of: scenePhase) { _, phase in
                    lock.handleScenePhase(
                        phase,
                        privacyScreenEnabled: appState.settings.privacyScreenEnabled
                    )
                    switch phase {
                    case .active: Haptics.shared.prepare()
                    case .background: Haptics.shared.teardown()
                    default: break
                    }
                }
        }
    }
}

enum AppTab: Hashable {
    case map
    case roster
    case timeline
    case settings
}

struct RootView: View {

    @Environment(AppState.self) private var app
    @Environment(AppLock.self) private var lock

    @State private var selection: AppTab = .map

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
                Tab("地图", systemImage: "map.fill", value: AppTab.map) {
                    MapScreen()
                }

                Tab("名单", systemImage: "person.2.fill", value: AppTab.roster) {
                    RosterScreen()
                }
                .badge(app.needsAttention.count)

                Tab("动态", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.timeline) {
                    TimelineScreen()
                }

                Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsScreen()
                }
            }
            .minimizableTabBar()

            if lock.isObscured, !lock.isLocked {
                PrivacyCurtain()
                    .zIndex(1)
            }

            if lock.isLocked {
                LockScreen()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: lock.isLocked)
        .animation(.easeInOut(duration: 0.12), value: lock.isObscured)
    }

    /// 切换 Tab 时给一记轻反馈
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue != selection { Haptics.shared.play(.selection) }
                selection = newValue
            }
        )
    }
}
