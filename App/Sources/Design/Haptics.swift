import CoreHaptics
import SwiftUI
import UIKit

/// 触感语汇表。
///
/// 前几项映射到系统标准反馈；后半段是用 CoreHaptics 手工编排的自定义波形——
/// 它们对应 App 里有「物理感」的动作（落针、聚焦、发出邀约），
/// 系统预设的 impact 表达不了那种「先一顿、再化开」的层次。
enum HapticCue: Equatable {
    // 系统标准
    case selection
    case lightTap
    case mediumTap
    case heavyTap
    case success
    case warning
    case error

    // 自定义波形
    /// 在地图上落下一枚标记：一记干脆的敲击，尾随一段迅速衰减的余震
    case pinDrop
    /// 城市气泡被选中：两下由弱到强的短促点击
    case cityFocus
    /// 发出邀约：绵长上扬，像一次呼气
    case waveSent
    /// 面板升起：极轻的连续起振
    case sheetRise
    /// 拨动开关到「开」
    case toggleOn
    /// 拨动开关到「关」
    case toggleOff
}

@MainActor
final class Haptics {

    static let shared = Haptics()

    private(set) var isSupported: Bool = false
    private var isEnabled: Bool = true
    /// 0.35 ~ 1.0，来自设置页
    private var intensityScale: Float = 1.0

    private var engine: CHHapticEngine?
    private var engineFailed = false

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private lazy var lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var softGenerator = UIImpactFeedbackGenerator(style: .soft)

    private init() {
        isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - 生命周期

    func configure(with settings: AppSettings) {
        isEnabled = settings.hapticsEnabled
        intensityScale = Float(min(max(settings.hapticIntensity, 0.35), 1.0))
        if isEnabled { prepare() }
    }

    /// 提前唤醒引擎，消除首次触发时约 20~50ms 的启动延迟
    func prepare() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightGenerator.prepare()
        startEngineIfNeeded()
    }

    /// 进入后台时释放引擎，避免占用触感硬件
    func teardown() {
        engine?.stop(completionHandler: nil)
    }

    // MARK: - 播放

    func play(_ cue: HapticCue) {
        guard isEnabled else { return }

        switch cue {
        case .selection:
            selectionGenerator.selectionChanged()
        case .lightTap:
            lightGenerator.impactOccurred(intensity: CGFloat(0.7 * intensityScale))
        case .mediumTap:
            mediumGenerator.impactOccurred(intensity: CGFloat(intensityScale))
        case .heavyTap:
            heavyGenerator.impactOccurred(intensity: CGFloat(intensityScale))
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        case .toggleOn:
            softGenerator.impactOccurred(intensity: CGFloat(0.85 * intensityScale))
        case .toggleOff:
            softGenerator.impactOccurred(intensity: CGFloat(0.5 * intensityScale))
        case .pinDrop, .cityFocus, .waveSent, .sheetRise:
            playCustom(cue)
        }
    }

    // MARK: - CoreHaptics

    private func startEngineIfNeeded() {
        guard isSupported, !engineFailed else { return }

        if engine == nil {
            do {
                let newEngine = try CHHapticEngine()
                newEngine.playsHapticsOnly = true
                newEngine.isAutoShutdownEnabled = true

                // 引擎可能被系统回收（来电、Siri 等），这里负责自愈
                newEngine.resetHandler = { [weak newEngine] in
                    try? newEngine?.start()
                }
                newEngine.stoppedHandler = { _ in }

                engine = newEngine
            } catch {
                engineFailed = true
                return
            }
        }

        do {
            try engine?.start()
        } catch {
            // 起不来就静默退回 UIKit 反馈，不影响主流程
            engineFailed = true
        }
    }

    private func playCustom(_ cue: HapticCue) {
        startEngineIfNeeded()

        guard isSupported, !engineFailed, let engine else {
            playFallback(for: cue)
            return
        }

        do {
            let pattern = try pattern(for: cue)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            playFallback(for: cue)
        }
    }

    private func playFallback(for cue: HapticCue) {
        switch cue {
        case .pinDrop: mediumGenerator.impactOccurred(intensity: CGFloat(intensityScale))
        case .cityFocus: lightGenerator.impactOccurred(intensity: CGFloat(0.8 * intensityScale))
        case .waveSent: notificationGenerator.notificationOccurred(.success)
        case .sheetRise: softGenerator.impactOccurred(intensity: CGFloat(0.4 * intensityScale))
        default: selectionGenerator.selectionChanged()
        }
    }

    private func pattern(for cue: HapticCue) throws -> CHHapticPattern {
        switch cue {
        case .pinDrop:
            // 一记敲击 + 0.22s 快速衰减的余震
            let strike = event(.hapticTransient, intensity: 0.95, sharpness: 0.72, at: 0)
            let ring = event(.hapticContinuous, intensity: 0.42, sharpness: 0.28, at: 0.015, duration: 0.22)
            let decay = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 1.0),
                    .init(relativeTime: 0.08, value: 0.45),
                    .init(relativeTime: 0.22, value: 0.0),
                ],
                relativeTime: 0.015
            )
            return try CHHapticPattern(events: [strike, ring], parameterCurves: [decay])

        case .cityFocus:
            // 由弱到强的两点，像"对准了"
            let first = event(.hapticTransient, intensity: 0.45, sharpness: 0.35, at: 0)
            let second = event(.hapticTransient, intensity: 0.85, sharpness: 0.65, at: 0.075)
            return try CHHapticPattern(events: [first, second], parameterCurves: [])

        case .waveSent:
            // 绵长上扬 + 收尾一记轻点
            let swell = event(.hapticContinuous, intensity: 0.55, sharpness: 0.22, at: 0, duration: 0.30)
            let rise = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.15),
                    .init(relativeTime: 0.20, value: 0.85),
                    .init(relativeTime: 0.30, value: 0.10),
                ],
                relativeTime: 0
            )
            let cap = event(.hapticTransient, intensity: 0.9, sharpness: 0.8, at: 0.30)
            return try CHHapticPattern(events: [swell, cap], parameterCurves: [rise])

        case .sheetRise:
            let lift = event(.hapticContinuous, intensity: 0.32, sharpness: 0.15, at: 0, duration: 0.16)
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.0),
                    .init(relativeTime: 0.09, value: 1.0),
                    .init(relativeTime: 0.16, value: 0.0),
                ],
                relativeTime: 0
            )
            return try CHHapticPattern(events: [lift], parameterCurves: [curve])

        default:
            let tap = event(.hapticTransient, intensity: 0.6, sharpness: 0.5, at: 0)
            return try CHHapticPattern(events: [tap], parameterCurves: [])
        }
    }

    private func event(
        _ type: CHHapticEvent.EventType,
        intensity: Float,
        sharpness: Float,
        at time: TimeInterval,
        duration: TimeInterval? = nil
    ) -> CHHapticEvent {
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1, intensity * intensityScale)),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ]
        if let duration {
            return CHHapticEvent(eventType: type, parameters: parameters, relativeTime: time, duration: duration)
        }
        return CHHapticEvent(eventType: type, parameters: parameters, relativeTime: time)
    }
}

// MARK: - SwiftUI 便捷入口

private struct HapticOnChangeModifier<V: Equatable>: ViewModifier {
    let cue: HapticCue
    let value: V

    func body(content: Content) -> some View {
        content.onChange(of: value) { _, _ in
            Haptics.shared.play(cue)
        }
    }
}

extension View {
    /// 值变化时播放触感
    func haptic<V: Equatable>(_ cue: HapticCue, trigger value: V) -> some View {
        modifier(HapticOnChangeModifier(cue: cue, value: value))
    }
}

/// 让按钮的按下瞬间也有反馈（系统按钮默认没有）
struct HapticButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var cue: HapticCue = .lightTap
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.shared.play(cue) }
            }
    }
}
