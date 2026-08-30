import SwiftUI
import UIKit

// MARK: - 备份文件（ShareLink 导出用）

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 设置页

struct SettingsScreen: View {

    @Environment(AppState.self) private var app
    @Environment(AppLock.self) private var lock

    @State private var isExporting = false
    @State private var exportDocument: BackupDocument?
    @State private var isImporting = false
    @State private var pendingImportData: Data?
    @State private var showImportChoice = false
    @State private var showImportError: String?
    @State private var importSummary: ImportSummary?
    @State private var showEraseConfirm = false
    @State private var showLockUnavailable = false

    var body: some View {
        NavigationStack {
            Form {
                privacySection
                hapticsSection
                appearanceSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: BackupService.suggestedFilename()
        ) { result in
            if case .success(let url) = result {
                exportDocument = nil
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImportData = try Data(contentsOf: url)
                showImportChoice = true
            } catch {
                showImportError = "读不出这个文件：\(error.localizedDescription)"
            }
        }
        .confirmationDialog("怎么导入？", isPresented: $showImportChoice, titleVisibility: .visible) {
            Button("合并（保留两边）") { finishImport(replace: false) }
            Button("覆盖（清空后导入）", role: .destructive) { finishImport(replace: true) }
            Button("取消", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("合并：同一个人以更新时间较新的为准。覆盖：本机数据会被备份里的内容替换。")
        }
        .alert("导入失败", isPresented: Binding(
            get: { showImportError != nil },
            set: { if !$0 { showImportError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(showImportError ?? "")
        }
        .alert("导入完成", isPresented: Binding(
            get: { importSummary != nil },
            set: { if !$0 { importSummary = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            if let summary = importSummary {
                Text("新增 \(summary.companionsAdded) 人，更新 \(summary.companionsUpdated) 人，新增 \(summary.encountersAdded) 条记录。")
            }
        }
        .alert("无法开启锁定", isPresented: $showLockUnavailable) {
            Button("好", role: .cancel) {}
        } message: {
            Text("这台设备没有设置面容 / 触控 ID 或密码。先在系统「设置」里添加一种，再回来开启。")
        }
        .confirmationDialog(
            "清空全部数据？",
            isPresented: $showEraseConfirm,
            titleVisibility: .visible
        ) {
            Button("全部清空", role: .destructive) {
                app.eraseAllLocalData()
                lock.configure(enabled: false)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有档案、相处记录和设置都会被删除，且无法恢复。建议先导出一份备份。")
        }
    }

    // MARK: 隐私

    private var privacySection: some View {
        Section {
            Toggle(isOn: app.settingsBinding(\.appLockEnabled)) {
                Label {
                    Text("App 锁")
                } icon: {
                    Image(systemName: lock.biometrySymbol)
                        .foregroundStyle(Palette.accent)
                }
            }
            .onChange(of: app.settings.appLockEnabled) { _, enabled in
                guard enabled else { return }
                if lock.canAuthenticate {
                    Task { await lock.authenticate() }
                } else {
                    var updated = app.settings
                    updated.appLockEnabled = false
                    app.updateSettings(updated)
                    showLockUnavailable = true
                }
            }
            .accessibilityHint("开启后需要\(lock.biometryLabel)才能进入")

            if app.settings.appLockEnabled {
                Button {
                    Task { await lock.authenticate() }
                } label: {
                    Label("立即锁定", systemImage: "lock.fill")
                }
            }

            Toggle(isOn: app.settingsBinding(\.privacyScreenEnabled)) {
                Label("后台模糊遮盖", systemImage: "eye.slash")
            }
            .accessibilityHint("切到多任务界面时，用毛玻璃盖住内容")

            Toggle(isOn: app.settingsBinding(\.maskNamesByDefault)) {
                Label("默认隐藏名字", systemImage: "person.crop.circle.badge.questionmark")
            }
            .accessibilityHint("名单里的名字会模糊显示，直到你点眼睛图标")
        } header: {
            Text("隐私")
        } footer: {
            Text("星图不联网、不申请任何系统权限。你的数据只存在这台设备上。")
        }
    }

    // MARK: 触感

    private var hapticsSection: some View {
        Section {
            Toggle(isOn: app.settingsBinding(\.hapticsEnabled)) {
                Label("触感反馈", systemImage: "iphone.radiowaves.left.and.right")
            }

            if app.settings.hapticsEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: app.settingsBinding(\.hapticIntensity),
                        in: 0.35...1.0
                    )
                    .onChange(of: app.settings.hapticIntensity) { _, _ in
                        Haptics.shared.play(.selection)
                    }
                }

                Button {
                    Haptics.shared.play(.pinDrop)
                } label: {
                    Label("试一下触感", systemImage: "hand.tap.fill")
                }
            }
        } header: {
            Text("触感")
        } footer: {
            Text("地图选点、升降面板、保存档案这些动作都有对应的原生触感。")
        }
    }

    // MARK: 外观

    private var appearanceSection: some View {
        Section("外观") {
            Picker("外观", selection: app.settingsBinding(\.appearance)) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            Picker("地图样式", selection: app.settingsBinding(\.mapSkin)) {
                ForEach(MapSkin.allCases) { skin in
                    Label(skin.label, systemImage: skin.symbolName).tag(skin)
                }
            }

            Toggle(isOn: app.settingsBinding(\.showHeatGlow)) {
                Label("城市光晕", systemImage: "sparkles")
            }
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            Button {
                Haptics.shared.play(.lightTap)
                do {
                    exportDocument = BackupDocument(data: try app.makeBackup())
                    isExporting = true
                } catch {
                    showImportError = "导出失败：\(error.localizedDescription)"
                }
            } label: {
                Label("导出备份（JSON）", systemImage: "square.and.arrow.up")
            }

            Button {
                Haptics.shared.play(.lightTap)
                isImporting = true
            } label: {
                Label("导入备份", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                Haptics.shared.play(.warning)
                showEraseConfirm = true
            } label: {
                Label("清空全部数据", systemImage: "trash")
            }
        } header: {
            Text("数据")
        } footer: {
            Text("\(app.companions.count) 条档案 · \(app.encounters.count) 条记录。备份文件是明文 JSON，请存放在自己信任的位置。")
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        Section("关于") {
            NavigationLink {
                PrivacyView()
            } label: {
                Label("隐私说明", systemImage: "hand.raised.fill")
            }
            NavigationLink {
                AboutView()
            } label: {
                Label("关于星图", systemImage: "info.circle")
            }
        }
    }

    private func finishImport(replace: Bool) {
        guard let data = pendingImportData else { return }
        pendingImportData = nil
        do {
            importSummary = try app.importBackup(data, replaceExisting: replace)
        } catch {
            showImportError = error.localizedDescription
        }
    }
}

// MARK: - 关于 / 隐私

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 76, height: 76)
                        .glassCircle()

                    Text("星图")
                        .font(.title2.weight(.bold))
                    Text("版本 \(Bundle.main.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section("技术") {
                LabeledContent("最低系统", value: "iOS 18")
                LabeledContent("界面", value: "SwiftUI · 液态玻璃")
                LabeledContent("地图", value: "MapKit · 仅中国大陆")
                LabeledContent("触感", value: "Core Haptics")
                LabeledContent("存储", value: "纯本地")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                Label {
                    Text("不联网")
                        .font(.headline)
                } icon: {
                    Image(systemName: "wifi.slash").foregroundStyle(Palette.accent)
                }
                Text("星图没有一行网络代码：不发请求、没有统计 SDK、没有云同步。所有数据只写在本机沙盒。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label {
                    Text("不申请权限")
                        .font(.headline)
                } icon: {
                    Image(systemName: "nosign").foregroundStyle(Palette.accent)
                }
                Text("不读通讯录、不定位、不访问相册。唯一的系统交互是可选的面容 / 触控 ID 解锁。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label {
                    Text("只到城市粒度")
                        .font(.headline)
                } icon: {
                    Image(systemName: "map").foregroundStyle(Palette.accent)
                }
                Text("地图上只标记到「市」一级。档案里没有、也不收集任何人的精确位置。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label {
                    Text("备份即明文")
                        .font(.headline)
                } icon: {
                    Image(systemName: "doc.text").foregroundStyle(Palette.accent)
                }
                Text("导出的备份是未加密的 JSON，请把它存在只有你自己能访问的位置。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("隐私说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Bundle {
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
