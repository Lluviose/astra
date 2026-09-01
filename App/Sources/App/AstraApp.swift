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
                    synchronizePrivacyWindow()
                }
                .onChange(of: appState.settings.appLockEnabled) { _, enabled in
                    lock.configure(enabled: enabled)
                    synchronizePrivacyWindow()
                }
                .onChange(of: appState.settings.privacyScreenEnabled) { _, _ in
                    synchronizePrivacyWindow()
                }
                .onChange(of: lock.isLocked) { _, _ in
                    synchronizePrivacyWindow()
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
                    synchronizePrivacyWindow()
                }
        }
    }

    /// UIWindow 级遮罩能覆盖所有 SwiftUI sheet。系统认证会短暂让场景进入 inactive，
    /// 此时保留已有解锁窗口，避免销毁正在等待的 LocalAuthentication 任务。
    @MainActor
    private func synchronizePrivacyWindow() {
        let controller = PrivacyWindowController.shared

        if scenePhase == .active {
            if lock.isConfigured, lock.isLocked {
                controller.showLock(using: lock)
            } else {
                controller.hide()
            }
            return
        }

        if controller.isShowingLock, lock.isAuthenticating { return }

        if appState.settings.privacyScreenEnabled || (lock.isConfigured && lock.isLocked) {
            controller.showPrivacy()
        } else {
            controller.hide()
        }
    }
}

enum AppTab: Hashable {
    case home
    case roster
    case timeline
    case achievements
    case settings
}

struct RootView: View {

    @Environment(AppState.self) private var app
    @Environment(AppLock.self) private var lock

    @State private var selection: AppTab = .home

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
                Tab("猎场", systemImage: "flame.fill", value: AppTab.home) {
                    HomeScreen()
                }

                Tab("名册", systemImage: "person.2.fill", value: AppTab.roster) {
                    RosterScreen()
                }
                .badge(app.needsAttention.count)

                Tab("记录册", systemImage: "book.closed.fill", value: AppTab.timeline) {
                    TimelineScreen()
                }

                Tab("成就册", systemImage: "crown.fill", value: AppTab.achievements) {
                    NavigationStack {
                        AchievementsScreen()
                    }
                }
                .badge(app.unseenUnlockCount)

                Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsScreen()
                }
            }
            .minimizableTabBar()

            if !lock.isConfigured {
                PrivacyCurtain()
                    .zIndex(2)
            } else if lock.isObscured, !lock.isLocked {
                PrivacyCurtain()
                    .zIndex(1)
            }

            if !app.pendingUnlocks.isEmpty, !lock.isLocked {
                UnlockOverlay(
                    achievements: app.pendingUnlocks,
                    onKeep: { app.dismissUnlocks() },
                    onOpenBook: {
                        app.dismissUnlocks()
                        selection = .achievements
                    }
                )
                .zIndex(1.5)
            }

            if lock.isConfigured, lock.isLocked {
                LockScreen()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: lock.isLocked)
        .animation(.easeInOut(duration: 0.12), value: lock.isObscured)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: app.pendingUnlocks.isEmpty)
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
