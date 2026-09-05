import SwiftUI

struct RewardOverlay: View {
    let events: [RewardEvent]
    let onDismiss: () -> Void
    let onOpenHall: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 16) {
                Label("王者战报结算", systemImage: "crown.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Palette.goldDeep)

                ForEach(events) { event in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(event.tint.color.opacity(0.16)).frame(width: 44, height: 44)
                            Image(systemName: event.symbolName).foregroundStyle(event.tint.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.headline)
                            Text(event.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onDismiss) {
                        Text("收下")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticButtonStyle())
                    .astraSurface(cornerRadius: 14)
                    .accessibilityIdentifier("dismiss-rewards")

                    Button(action: onOpenHall) {
                        Text("去王者殿堂")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(Palette.background)
                            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticButtonStyle())
                }
            }
            .padding(20)
            .astraSurface(cornerRadius: 28)
            .frame(maxWidth: 480)
            .padding(.horizontal, 26)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.90)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) { appeared = true }
        }
    }
}
