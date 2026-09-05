import SwiftUI

struct PrivacyButton: View {
    @Environment(AppState.self) private var app
    var body: some View {
        Button { app.toggleNamesRevealed() } label: {
            Image(systemName: app.namesRevealed ? "eye.slash" : "eye")
        }
        .accessibilityLabel(app.namesRevealed ? "隐藏代号与照片" : "显示代号与照片")
        .accessibilityIdentifier("privacy-toggle")
    }
}

struct SettingsButton: View {
    @State private var isPresented = false
    var body: some View {
        Button { isPresented = true } label: { Image(systemName: "gearshape") }
            .accessibilityLabel("设置")
            .accessibilityIdentifier("open-settings")
            .sheet(isPresented: $isPresented) { SettingsScreen() }
    }
}
