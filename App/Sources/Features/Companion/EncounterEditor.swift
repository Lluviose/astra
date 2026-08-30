import SwiftUI

/// 相处记录编辑器（新增 / 编辑）
struct EncounterEditor: View {

    let initial: Encounter

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Encounter
    @State private var costText: String
    @State private var showDeleteConfirm = false

    private var isNew: Bool { !app.encounters.contains { $0.id == initial.id } }

    private var companion: Companion? { app.companion(id: initial.companionID) }

    init(encounter: Encounter) {
        self.initial = encounter
        _draft = State(initialValue: encounter)
        _costText = State(initialValue: encounter.cost.map { String(Int($0)) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("时间", selection: $draft.date)
                }

                Section("类型") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EncounterKind.allCases) { kind in
                                kindChip(kind)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section("细节") {
                    TextField("地点（如：静安那家日料）", text: $draft.place)
                    HStack {
                        Text("花费")
                        Spacer()
                        TextField("0", text: $costText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: costText) { _, newValue in
                                draft.cost = Double(newValue.filter { $0.isNumber })
                            }
                        Text("元")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("感受")
                        Spacer()
                        moodPicker
                    }
                }

                Section("备注") {
                    TextField("写下点什么", text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !isNew {
                    Section {
                        Button("删除这条记录", role: .destructive) {
                            Haptics.shared.play(.warning)
                            showDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "记一笔" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        app.upsert(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Palette.accent)
                }
            }
            .confirmationDialog(
                "删除这条记录？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    app.delete(encounterID: initial.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func kindChip(_ kind: EncounterKind) -> some View {
        Button {
            Haptics.shared.play(.selection)
            draft.kind = kind
        } label: {
            HStack(spacing: 5) {
                if draft.kind == kind {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                }
                Image(systemName: kind.symbolName).font(.system(size: 12, weight: .semibold))
                Text(kind.label).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(draft.kind == kind ? .white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if draft.kind == kind {
                    Capsule().fill(kind.tint.gradient)
                }
            }
            .glassCapsule(interactive: true, shadowRadius: 8)
        }
        .buttonStyle(HapticButtonStyle(cue: .selection))
    }

    private var moodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Array([("😣", 1), ("😐", 2), ("🙂", 3), ("😊", 4), ("🤩", 5)]), id: \.1) { emoji, value in
                Button {
                    Haptics.shared.play(.selection)
                    draft.mood = value
                } label: {
                    Text(emoji)
                        .font(.title3)
                        .opacity(draft.mood == value ? 1 : 0.3)
                        .scaleEffect(draft.mood == value ? 1.15 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: draft.mood)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("感受 \(value) 分")
            }
        }
    }
}
