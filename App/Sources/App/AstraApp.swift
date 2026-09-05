import SwiftUI

@main
struct AstraApp: App {

    @State private var appState: AppState = {
        #if DEBUG
        if let reviewState = UIReviewFixtures.makeStateIfRequested() { return reviewState }
        #endif
        return AppState()
    }()
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(lock)
                .modifier(UIReviewDisplayModifier())
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
    case collection, journal, hall
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(AppLock.self) private var lock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: AppTab = .collection
    @State private var showsSaved = false

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                Tab("后宫", systemImage: "rectangle.stack", value: AppTab.collection) {
                    HaremGalleryScreen()
                }
                Tab("战绩", systemImage: "book.closed", value: AppTab.journal) {
                    TimelineScreen()
                }
                Tab("殿堂", systemImage: "crown", value: AppTab.hall) {
                    NavigationStack { RoyalHallScreen() }
                }
                .badge(app.unseenUnlockCount)
            }
            .toolbarBackground(Palette.surface, for: .tabBar)
            .accessibilityHidden(lock.isLocked)
            .allowsHitTesting(!lock.isLocked)

            if !lock.isConfigured || (lock.isObscured && !lock.isLocked) {
                PrivacyCurtain().zIndex(1)
            }
            if lock.isConfigured, lock.isLocked {
                LockScreen().transition(.opacity).zIndex(2)
            }
        }
        .overlay(alignment: .top) {
            if showsSaved, !lock.isLocked, !lock.isObscured {
                Label(app.pendingRewards.isEmpty && app.pendingUnlocks.isEmpty ? "记录已保存" : "记录已保存 · 收藏有新进展", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.background)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Palette.ink, in: Capsule())
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("record-saved")
                    .transition(.opacity)
            }
        }
        .task(id: app.recordSaveToken) {
            guard app.recordSaveToken > 0 else { return }
            showsSaved = true
            do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
            showsSaved = false
        }
        .onChange(of: selection) { _, _ in Haptics.shared.play(.selection) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showsSaved)
        .animation(.easeInOut(duration: 0.15), value: lock.isLocked)
    }
}

/// UI review overrides only exist in Debug; production follows system settings.
private struct UIReviewDisplayModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           ProcessInfo.processInfo.arguments.contains("--ui-large-type") {
            content.dynamicTypeSize(.accessibility3)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
