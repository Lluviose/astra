import SwiftUI

/// 动态页：月度统计 + 时间线
struct TimelineScreen: View {

    @Environment(AppState.self) private var app

    @State private var isPickingCompanion = false
    @State private var newEncounter: Encounter?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsGrid
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    barChart
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("近 6 个月见面频率")
                }

                let sections = app.timelineSections()
                if sections.isEmpty {
                    Section {
                        EmptyStateView(
                            symbol: "chart.line.downtrend.xyaxis",
                            title: "还没有相处记录",
                            message: "在详情页或这里记下每一次见面、通话和礼物，时间线会慢慢丰富起来。",
                            actionTitle: "记一笔",
                            action: { isPickingCompanion = true }
                        )
                    }
                } else {
                    ForEach(sections, id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.encounters) { encounter in
                                if let companion = app.companion(id: encounter.companionID) {
                                    NavigationLink(value: companion.id) {
                                        EncounterRow(encounter: encounter)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            app.delete(encounterID: encounter.id)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("动态")
            .navigationDestination(for: UUID.self) { id in
                CompanionDetailView(companionID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.shared.play(.lightTap)
                        isPickingCompanion = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("记一笔")
                }
            }
        }
        .sheet(isPresented: $isPickingCompanion) {
            CompanionPickerSheet { companion in
                newEncounter = Encounter(companionID: companion.id, cityID: companion.cityID)
            }
        }
        .sheet(item: $newEncounter) { encounter in
            EncounterEditor(encounter: encounter)
        }
    }

    // MARK: 统计

    private var statsGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatTile(
                    value: "\(app.stats.activeCount)",
                    caption: "进行中",
                    systemImage: "heart.fill",
                    tint: Palette.accent
                )
                StatTile(
                    value: "\(app.stats.cityCount)",
                    caption: "城市",
                    systemImage: "map.fill",
                    tint: Color(red: 0.35, green: 0.62, blue: 0.95)
                )
            }
            GridRow {
                StatTile(
                    value: "\(app.stats.meetupsThisMonth)",
                    caption: "本月见面",
                    systemImage: "person.2.fill",
                    tint: Color(red: 0.30, green: 0.75, blue: 0.60)
                )
                StatTile(
                    value: Format.money(app.stats.spendThisMonth),
                    caption: "本月花费",
                    systemImage: "yensign.circle.fill",
                    tint: Color(red: 0.98, green: 0.66, blue: 0.28)
                )
            }
        }
    }

    // MARK: 近 6 个月柱状图（纯 SwiftUI，无第三方库）

    private var barChart: some View {
        let data = monthlyMeetupCounts
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("共 \(data.reduce(0) { $0 + $1.count }) 次见面")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let mood = app.stats.averageMood {
                    Text(String(format: "平均感受 %.1f", mood))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Text("\(item.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(item.count > 0 ? Palette.accent : .secondary.opacity(0.5))
                            .contentTransition(.numericText())

                        Capsule(style: .continuous)
                            .fill(
                                item.count > 0
                                    ? AnyShapeStyle(Palette.accent.gradient)
                                    : AnyShapeStyle(Color.secondary.opacity(0.12))
                            )
                            .frame(height: max(4, CGFloat(item.count) * 12))

                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120, alignment: .bottom)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: data.map(\.count))
        }
        .padding(.vertical, 6)
    }

    private var monthlyMeetupCounts: [(label: String, count: Int)] {
        let calendar = Calendar.current
        var months: [Date] = []
        guard let now = calendar.dateInterval(of: .month, for: Date())?.start else { return [] }
        for offset in stride(from: -5, through: 0, by: 1) {
            if let month = calendar.date(byAdding: .month, value: offset, to: now) {
                months.append(month)
            }
        }

        let labelFormatter = DateFormatter()
        labelFormatter.setLocalizedDateFormatFromTemplate("MMM")

        return months.map { month in
            guard let interval = calendar.dateInterval(of: .month, for: month) else {
                return (labelFormatter.string(from: month), 0)
            }
            let count = app.encounters.filter {
                $0.kind.isInPerson && $0.date >= interval.start && $0.date < interval.end
            }.count
            return (labelFormatter.string(from: month), count)
        }
    }
}

// MARK: - 选人面板

struct CompanionPickerSheet: View {

    let onSelect: (Companion) -> Void

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var filtered: [Companion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.activeCompanions.filter { companion in
            q.isEmpty
                || companion.displayName.lowercased().contains(q)
                || app.cityName(for: companion).contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    EmptyStateView(
                        symbol: "person.crop.circle.badge.questionmark",
                        title: "没有匹配的人",
                        message: "换一个名字或城市试试。"
                    )
                } else {
                    ForEach(filtered) { companion in
                        Button {
                            Haptics.shared.play(.selection)
                            dismiss()
                            onSelect(companion)
                        } label: {
                            CompanionRow(companion: companion)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("和谁的记录？")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "名字 / 城市")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
