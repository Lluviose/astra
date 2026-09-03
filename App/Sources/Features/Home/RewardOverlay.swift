import SwiftUI

struct RewardOverlay: View {
    let events: [RewardEvent]
    let onDismiss: () -> Void
    let onOpenHall: () -> Void

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
                    Button("收下", action: onDismiss)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .glassCard(cornerRadius: 14, interactive: true, shadowRadius: 6)
                    Button("去王者殿堂", action: onOpenHall)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Palette.goldDeep.gradient, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding(20)
            .glassCard(cornerRadius: 28, shadowRadius: 18)
            .padding(.horizontal, 26)
            .scaleEffect(appeared ? 1 : 0.90)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { appeared = true }
        }
    }
}
