import SwiftUI

/// 一个人的经期：预测、日历、记录和提醒。
struct PeriodTrackerView: View {
    let companionID: UUID

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var editing: PeriodRecord?
    @State private var isCreating = false
    @State private var pendingDeletion: PeriodRecord?
    @State private var monthOffset = 0

    private var companion: Companion? { app.companion(id: companionID) }
    private var snapshot: PeriodSnapshot { app.periodSnapshot(for: companionID) }
    private var records: [PeriodRecord] { app.periodRecords(for: companionID) }

    var body: some View {
        NavigationStack {
            Group {
                if let companion {
                    content(companion)
                } else {
                    EmptyStateView(symbol: "person.crop.circle.badge.questionmark", title: "档案不存在", message: "这页可能已经从名册里撕掉了。")
                }
            }
            .navigationTitle("经期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.shared.play(.selection)
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("记一次经期")
                    .disabled(companion == nil)
                }
            }
            .sheet(isPresented: $isCreating) {
                if companion != nil {
                    PeriodRecordEditor(companionID: companionID, record: nil)
                }
            }
            .sheet(item: $editing) { record in
                PeriodRecordEditor(companionID: companionID, record: record)
            }
            .confirmationDialog(
                "删除这条经期？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { record in
                Button("删除", role: .destructive) {
                    app.delete(periodRecordID: record.id)
                }
                Button("取消", role: .cancel) {}
            } message: { record in
                Text("\(DateFormatter.dayFull.string(from: record.startDate)) 这次会从预测里拿掉。")
            }
        }
    }

    private func content(_ companion: Companion) -> some View {
        List {
            forecastSection(companion)
            if companion.periodTrackingEnabled {
                actionsSection
                calendarSection
                historySection
            }
            settingsSection(companion)
        }
        .listStyle(.insetGrouped)
        .astraListBackground()
    }

    private func forecastSection(_ companion: Companion) -> some View {
        let snap = snapshot
        return Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(snap.headline, systemImage: snap.phase.symbolName)
                    .font(.headline)
                    .foregroundStyle(snap.phase.tint)
                    .fixedSize(horizontal: false, vertical: true)
                Text(snap.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let ovulation = snap.forecast.ovulation, snap.loggedCount > 0 {
                    Text("排卵大约 \(DateFormatter.dayShort.string(from: ovulation))")
                        .font(.caption)
                        .foregroundStyle(Palette.iris)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(app.namesRevealed ? companion.displayName : "周期预测")
        } footer: {
            Text("预测用来避开会来的日子，不能替代医生，也不能当避孕依据。")
        }
    }

    private var actionsSection: some View {
        let snap = snapshot
        return Section {
            if snap.phase != .bleeding {
                Button {
                    _ = app.markPeriodStarted(for: companionID)
                } label: {
                    Label("今天来了", systemImage: "drop.fill")
                }
            }
            if snap.openRecord != nil || snap.phase == .bleeding {
                Button {
                    _ = app.markPeriodEnded(for: companionID)
                } label: {
                    Label("今天走了", systemImage: "checkmark.circle")
                }
            }
            Button {
                isCreating = true
            } label: {
                Label("补记一次", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var calendarSection: some View {
        let calendar = Calendar.current
        let month = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        return Section {
            PeriodMonthGrid(
                month: month,
                records: records,
                forecast: snapshot.forecast
            )
            HStack {
                Button {
                    monthOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("上个月")
                Spacer()
                Text(DateFormatter.monthTitle.string(from: month))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    monthOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("下个月")
            }
            .buttonStyle(.borderless)
        } header: {
            Text("日历")
        } footer: {
            Text("实心是记下的经期，描边是预测，紫色是易孕窗口。")
        }
    }

    private var historySection: some View {
        Section {
            if records.isEmpty {
                Text("还没有记下的经期。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    Button {
                        editing = record
                    } label: {
                        PeriodRecordRow(record: record)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeletion = record
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("记下的经期")
                Spacer()
                Text("\(records.count) 次")
            }
        }
    }

    private func settingsSection(_ companion: Companion) -> some View {
        Section {
            Toggle("为她记经期", isOn: Binding(
                get: { companion.periodTrackingEnabled },
                set: { app.setPeriodTracking($0, for: companionID) }
            ))

            if companion.periodTrackingEnabled {
                Picker("她说的周期", selection: typicalCycleBinding(companion)) {
                    Text("还不确定").tag(Int?.none)
                    ForEach([21, 24, 26, 28, 30, 32, 35, 40], id: \.self) { days in
                        Text("\(days) 天").tag(Int?.some(days))
                    }
                }
                Picker("她说的经期", selection: typicalPeriodBinding(companion)) {
                    Text("还不确定").tag(Int?.none)
                    ForEach([3, 4, 5, 6, 7, 8], id: \.self) { days in
                        Text("\(days) 天").tag(Int?.some(days))
                    }
                }
                Toggle("经期开始前提醒", isOn: notifyBinding(companion, \.periodNotifyEnabled))
                if companion.periodNotifyEnabled {
                    Picker("提前几天", selection: leadBinding(companion)) {
                        Text("提前 1 天").tag(1)
                        Text("提前 2 天").tag(2)
                        Text("提前 3 天").tag(3)
                    }
                    Toggle("易孕窗口和排卵日", isOn: notifyBinding(companion, \.periodNotifyFertile))
                }
            }
        } header: {
            Text("提醒与先验")
        } footer: {
            Text("通知只在本机发。设置里还要打开「经期本机通知」。先验只在记录很少时帮忙，不会盖过她实际来的日子。")
        }
    }

    private func typicalCycleBinding(_ companion: Companion) -> Binding<Int?> {
        Binding(
            get: { companion.typicalCycleDays },
            set: { value in
                guard var updated = app.companion(id: companionID) else { return }
                updated.typicalCycleDays = CycleEngine.clampCycle(value)
                app.upsert(updated)
            }
        )
    }

    private func typicalPeriodBinding(_ companion: Companion) -> Binding<Int?> {
        Binding(
            get: { companion.typicalPeriodDays },
            set: { value in
                guard var updated = app.companion(id: companionID) else { return }
                updated.typicalPeriodDays = CycleEngine.clampPeriod(value)
                app.upsert(updated)
            }
        )
    }

    private func leadBinding(_ companion: Companion) -> Binding<Int> {
        Binding(
            get: { companion.periodNotifyLeadDays },
            set: { value in
                guard var updated = app.companion(id: companionID) else { return }
                updated.periodNotifyLeadDays = CycleEngine.clampLeadDays(value)
                app.upsert(updated)
            }
        )
    }

    private func notifyBinding(_ companion: Companion, _ keyPath: WritableKeyPath<Companion, Bool>) -> Binding<Bool> {
        Binding(
            get: { companion[keyPath: keyPath] },
            set: { value in
                guard var updated = app.companion(id: companionID) else { return }
                updated[keyPath: keyPath] = value
                app.upsert(updated)
            }
        )
    }

}

struct PeriodRecordRow: View {
    let record: PeriodRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: record.flow.symbolName)
                .foregroundStyle(Palette.coral)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ChevronHint()
        }
    }

    private var title: String {
        if let end = record.endDate, !Calendar.current.isDate(end, inSameDayAs: record.startDate) {
            return "\(DateFormatter.dayShort.string(from: record.startDate)) – \(DateFormatter.dayShort.string(from: end))"
        }
        return DateFormatter.dayShort.string(from: record.startDate)
    }

    private var subtitle: String {
        var parts = [record.flow.label, "\(record.durationDays()) 天"]
        if record.endDate == nil { parts.append("还没走") }
        if !record.symptoms.isEmpty { parts.append(record.symptoms.prefix(2).map(\.label).joined(separator: "、")) }
        return parts.joined(separator: " · ")
    }
}

struct PeriodMonthGrid: View {
    let month: Date
    let records: [PeriodRecord]
    let forecast: CycleForecast

    private var calendar: Calendar { .current }

    var body: some View {
        let days = daysInMonth
        let weekdaySymbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<7, id: \.self) { offset in
                    let index = (firstWeekday - 1 + offset) % 7
                    Text(weekdaySymbols[index])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 32)
                }
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var leadingBlanks: Int {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let weekday = calendar.component(.weekday, from: start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private func dayCell(_ day: Date) -> some View {
        let phase = CycleEngine.dayKind(day, records: records, forecast: forecast, calendar: calendar)
        let isToday = calendar.isDateInToday(day)
        let logged = records.contains { $0.contains(day, asOf: Date(), calendar: calendar) }
        return Text("\(calendar.component(.day, from: day))")
            .font(.caption.weight(isToday ? .bold : .medium))
            .foregroundStyle(logged || phase == .bleeding ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background {
                Circle()
                    .fill(logged || phase == .bleeding ? Palette.coral : Color.clear)
                if !logged {
                    switch phase {
                    case .predictedBleeding:
                        Circle().stroke(Palette.coral, lineWidth: 1.5)
                    case .ovulation:
                        Circle().fill(Palette.iris.opacity(0.9))
                    case .fertile:
                        Circle().fill(Palette.iris.opacity(0.22))
                    default:
                        EmptyView()
                    }
                }
            }
            .foregroundStyle(phase == .ovulation && !logged ? Color.white : (logged || phase == .bleeding ? Color.white : Color.primary))
            .accessibilityLabel(accessibility(day: day, phase: phase, logged: logged))
    }

    private func accessibility(day: Date, phase: CyclePhase, logged: Bool) -> String {
        let date = DateFormatter.dayShort.string(from: day)
        if logged { return "\(date) 已记经期" }
        if phase != .unknown && phase != .follicular && phase != .luteal {
            return "\(date) \(phase.label)"
        }
        return date
    }
}

struct PeriodRecordEditor: View {
    let companionID: UUID
    let record: PeriodRecord?

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var hasEnd: Bool
    @State private var endDate: Date
    @State private var flow: PeriodFlow
    @State private var symptoms: Set<PeriodSymptom>
    @State private var notes: String

    init(companionID: UUID, record: PeriodRecord?) {
        self.companionID = companionID
        self.record = record
        let start = record?.startDate ?? Date()
        _startDate = State(initialValue: start)
        _hasEnd = State(initialValue: record?.endDate != nil)
        _endDate = State(initialValue: record?.endDate ?? start)
        _flow = State(initialValue: record?.flow ?? .medium)
        _symptoms = State(initialValue: record?.symptoms ?? [])
        _notes = State(initialValue: record?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("开始", selection: $startDate, displayedComponents: .date)
                    Toggle("已经结束", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("结束", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("流量") {
                    PillPicker(
                        options: PeriodFlow.allCases.map {
                            PillOption(value: $0, title: $0.label, systemImage: $0.symbolName)
                        },
                        selection: $flow,
                        tint: Palette.coral,
                        scrollable: true
                    )
                }
                Section("感觉（可选）") {
                    FlowLayout(spacing: 7, lineSpacing: 8) {
                        ForEach(PeriodSymptom.allCases) { symptom in
                            RecordChoice(
                                title: symptom.label,
                                isOn: symptoms.contains(symptom),
                                tint: Palette.coral,
                                compact: true
                            ) {
                                if symptoms.contains(symptom) {
                                    symptoms.remove(symptom)
                                } else {
                                    symptoms.insert(symptom)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("备注") {
                    TextField("可选", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(record == nil ? "记一次经期" : "改这次经期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: hasEnd) { _, enabled in
                if enabled, endDate < startDate { endDate = startDate }
            }
            .onChange(of: startDate) { _, newStart in
                if hasEnd, endDate < newStart { endDate = newStart }
            }
        }
    }

    private func save() {
        var updated = record ?? PeriodRecord(companionID: companionID, startDate: startDate, flow: flow)
        updated.startDate = startDate
        updated.endDate = hasEnd ? endDate : nil
        updated.flow = flow
        updated.symptoms = symptoms
        updated.notes = notes
        app.upsert(updated)
        dismiss()
    }
}
