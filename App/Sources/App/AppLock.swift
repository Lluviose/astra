import LocalAuthentication
import Observation
import SwiftUI

/// App 锁。这类数据被别人随手翻到的代价很高，所以默认提供面容 / 触控 / 密码解锁，
/// 并在切到后台时给多任务卡片盖一层毛玻璃。
@MainActor
@Observable
final class AppLock {

    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var lastErrorMessage: String?
    /// 首帧先保持隐私遮罩，直到 App 设置已经被读取并应用。
    private(set) var isConfigured = false

    /// 切后台时是否要盖住内容
    var isObscured = false

    private var isEnabled = false

    // MARK: - 设备能力

    var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "面容 ID"
        case .touchID: return "触控 ID"
        case .opticID: return "光学 ID"
        default: return "设备密码"
        }
    }

    var biometrySymbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }

    /// 设备是否设置了任意一种锁（生物识别或数字密码）
    var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // MARK: - 生命周期

    /// 设置变化 / 冷启动时调用
    func configure(enabled: Bool, lockNow: Bool = false) {
        isEnabled = enabled
        isConfigured = true
        if !enabled {
            isLocked = false
            lastErrorMessage = nil
        } else if lockNow {
            isLocked = true
        }
    }

    /// 立即进入锁屏；锁屏视图出现后会发起系统验证。
    func lockNow() {
        guard isEnabled else { return }
        isObscured = false
        lastErrorMessage = nil
        isLocked = true
    }

    /// 场景状态变化。
    /// - `.inactive`（下拉控制中心、进入多任务）只盖遮罩，不上锁，否则一个系统弹窗就会把人锁在外面；
    /// - `.background`（真的离开了）才上锁。
    func handleScenePhase(_ phase: ScenePhase, privacyScreenEnabled: Bool) {
        switch phase {
        case .active:
            isObscured = false
        case .inactive:
            isObscured = privacyScreenEnabled
        case .background:
            isObscured = privacyScreenEnabled
            if isEnabled { isLocked = true }
        @unknown default:
            break
        }
    }

    // MARK: - 解锁

    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "取消"

        // 设备完全没有设锁时不能把用户关在门外
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            isLocked = false
            lastErrorMessage = nil
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁星图"
            )
            if success {
                isLocked = false
                lastErrorMessage = nil
                Haptics.shared.play(.success)
            } else {
                lastErrorMessage = "验证未通过"
                Haptics.shared.play(.error)
            }
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel {
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "验证失败，请重试"
            Haptics.shared.play(.error)
        }
    }
}

// MARK: - 锁屏界面

struct LockScreen: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            Palette.heroGradient.ignoresSafeArea()

            VStack(spacing: 22) {
                AstraMark()
                    .scaleEffect(1.7)
                    .frame(width: 104, height: 104)

                VStack(spacing: 6) {
                    Text("星图已锁定")
                        .font(.system(.title, design: .serif))
                        .foregroundStyle(.white)
                    Text(lock.lastErrorMessage ?? "用\(lock.biometryLabel)继续")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button {
                    Task { await lock.authenticate() }
                } label: {
                    PrimaryActionLabel(title: lock.isAuthenticating ? "正在验证…" : "解锁星图", systemImage: lock.biometrySymbol, onDark: true)
                }
                .buttonStyle(HapticButtonStyle())
                .frame(maxWidth: 260)
                .disabled(lock.isAuthenticating)
            }
        }
        .task { await lock.authenticate() }
    }
}

/// 极简星点背景，呼应 App 名字
struct StarfieldBackground: View {
    var body: some View {
        Canvas { context, size in
            // 固定排布，不引入随机源，保证每帧一致
            var seed: UInt64 = 0x5EED
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double((seed >> 33) % 10_000) / 10_000
            }
            for _ in 0..<90 {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.6 + next() * 1.6
                let opacity = 0.25 + next() * 0.55
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// 多任务切换卡片上的遮罩
struct PrivacyCurtain: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Palette.background)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                AstraMark(color: Palette.accent)
                Text("星图")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)
        }
        .transition(.opacity)
    }
}

/// 单独的高层级窗口，确保隐私遮罩 / 解锁页能盖住 SwiftUI 的 sheet、照片查看器和系统式弹层。
/// 仅把 UI 放到本 App 的 UIWindowScene 上，不创建新的数据副本。
@MainActor
final class PrivacyWindowController {

    static let shared = PrivacyWindowController()

    private enum Mode: Equatable {
        case privacy
        case lock
    }

    private var mode: Mode?
    private var windows: [ObjectIdentifier: UIWindow] = [:]
    private var previousKeyWindows: [ObjectIdentifier: UIWindow] = [:]

    var isShowingLock: Bool { mode == .lock }

    func showPrivacy() {
        show(mode: .privacy, lock: nil)
    }

    func showLock(using lock: AppLock) {
        show(mode: .lock, lock: lock)
    }

    func hide() {
        for (id, window) in windows {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindows[id]?.makeKey()
        }
        windows.removeAll()
        previousKeyWindows.removeAll()
        mode = nil
    }

    private func show(mode newMode: Mode, lock: AppLock?) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let liveIDs = Set(scenes.map { ObjectIdentifier($0) })

        let staleIDs = windows.keys.filter { !liveIDs.contains($0) }
        for id in staleIDs {
            windows.removeValue(forKey: id)?.isHidden = true
            previousKeyWindows[id] = nil
        }

        let modeChanged = mode != newMode
        mode = newMode

        for scene in scenes {
            let id = ObjectIdentifier(scene)
            let window: UIWindow
            if let existing = windows[id] {
                window = existing
            } else {
                window = UIWindow(windowScene: scene)
                window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
                window.backgroundColor = .clear
                windows[id] = window
            }

            if modeChanged || window.rootViewController == nil {
                let rootView: AnyView
                switch newMode {
                case .privacy:
                    rootView = AnyView(
                        ZStack {
                            Color(uiColor: .systemBackground).ignoresSafeArea()
                            PrivacyCurtain()
                        }
                    )
                case .lock:
                    guard let lock else { continue }
                    rootView = AnyView(LockScreen().environment(lock))
                }

                let host = UIHostingController(rootView: rootView)
                host.view.backgroundColor = .clear
                window.rootViewController = host
            }

            window.isUserInteractionEnabled = newMode == .lock
            if newMode == .lock {
                if previousKeyWindows[id] == nil {
                    previousKeyWindows[id] = scene.windows.first {
                        $0 !== window && $0.isKeyWindow
                    }
                }
                window.makeKeyAndVisible()
            } else {
                if window.isKeyWindow { previousKeyWindows[id]?.makeKey() }
                window.isHidden = false
            }
        }
    }
}
