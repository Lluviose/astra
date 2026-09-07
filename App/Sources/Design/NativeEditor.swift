import SwiftUI
import UIKit

struct NativeEditorStep {
    let title: String
    let subtitle: String
    let symbol: String
}

/// 原生导航下面的步骤栏。固定在表单上方，长表单滚动时仍能换页。
struct NativeEditorHeader: View {
    let steps: [NativeEditorStep]
    @Binding var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: steps[selection].symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 42, height: 42)
                    .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    Text(steps[selection].title).font(.headline)
                    Text(steps[selection].subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("\(selection + 1) / \(steps.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .contentTransition(reduceMotion ? .opacity : .numericText())
                    .accessibilityLabel("第 \(selection + 1) 步，共 \(steps.count) 步")
            }
            if typeSize.isAccessibilitySize {
                Picker("切换步骤", selection: $selection) { stepOptions }
                    .pickerStyle(.menu)
            } else {
                Picker("切换步骤", selection: $selection) { stepOptions }
                    .pickerStyle(.segmented)
            }
            ProgressView(value: Double(selection + 1), total: Double(steps.count))
                .tint(Palette.accent)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.regularMaterial)
    }

    private var stepOptions: some View {
        ForEach(steps.indices, id: \.self) { index in
            Text(steps[index].title).tag(index)
        }
    }
}

enum NativeEditorMotion {
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.46, dampingFraction: 0.88)
    }

    static func transition(forward: Bool, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let direction: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .modifier(active: PageMotion(offset: 28 * direction, opacity: 0, blur: 3), identity: .identity),
            removal: .modifier(active: PageMotion(offset: -14 * direction, opacity: 0, blur: 1), identity: .identity)
        )
    }

    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private struct PageMotion: ViewModifier {
        let offset: CGFloat
        let opacity: Double
        let blur: CGFloat
        static let identity = PageMotion(offset: 0, opacity: 1, blur: 0)

        func body(content: Content) -> some View {
            content
                .opacity(opacity)
                .offset(x: offset)
                .blur(radius: blur)
        }
    }
}

/// 表单内的选择按钮：稳定的勾选位置、44pt 点击区、系统层级色，无投影堆叠。
struct RecordChoice: View {
    let title: String
    var systemImage: String?
    var isOn = false
    var tint: Color = Palette.accent
    var compact = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.shared.play(isOn ? .toggleOff : .toggleOn)
            withAnimation(NativeEditorMotion.animation(reduceMotion: reduceMotion)) { action() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : (systemImage ?? "circle"))
                    .font(.caption.weight(.semibold))
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                Text(title)
                    .font(compact ? .subheadline : .body)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(isOn ? tint : Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(isOn ? tint.opacity(0.13) : Color(uiColor: .tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isOn ? tint.opacity(0.45) : Color.secondary.opacity(0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(NativeChoicePressStyle())
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

private struct NativeChoicePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.24, dampingFraction: 0.78),
                       value: configuration.isPressed)
    }
}
