import React, { useState } from "react";
import { View, Text, Pressable, ScrollView } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { useApp } from "../data/store";
import { filterEntries, kindLabels, localDate } from "../domain/model";
import { Screen, Avatar, Name, Icon, IconButton, Chip, Empty, PageTitle, Segments, SearchField, c, s } from "../design/ui";

export default function JournalScreen() {
  const { month: requestedMonth } = useLocalSearchParams<{ month?: string }>();
  const { data, hidden, mutate, notify } = useApp();
  const [query, setQuery] = useState(""), [kind, setKind] = useState("all"), [person, setPerson] = useState("all"), [thisMonth, setThisMonth] = useState(false), [filters, setFilters] = useState(false), [expanded, setExpanded] = useState(false);
  const month = thisMonth ? localDate().slice(0, 7) : requestedMonth || "all";
  const entries = filterEntries(data, query, kind, person, month);
  const followups = data.entries.filter(e => e.followUp && !e.completed);
  const filtered = !!query || kind !== "all" || person !== "all" || month !== "all";
  async function complete(id: string) {
    try { await mutate(d => ({ ...d, entries: d.entries.map(e => e.id === id ? { ...e, completed: !e.completed } : e) })); notify("跟进状态已更新"); }
    catch { notify("保存失败，请重试"); }
  }
  return <Screen>
    <PageTitle title="战绩" subtitle="相处有日期，记忆有细节" count={data.entries.length} />
    <View style={[s.row, { gap: 8, marginBottom: 13 }]}><View style={{ flex: 1 }}><SearchField label="搜索战绩" value={query} onChangeText={setQuery} placeholder="人物、地点或记忆" /></View><IconButton name="sliders" label="筛选记录" active={filters || person !== "all" || month !== "all"} onPress={() => setFilters(!filters)} /></View>
    <View style={{ borderBottomWidth: 1, borderColor: c.line, marginBottom: 21 }}><Segments items={[["all", "全部"], ["intimacy", "亲密"], ["date", "约会"], ["missed", "未发生"]]} value={kind} onChange={setKind} /></View>
    {filters && <View style={{ backgroundColor: c.paper, padding: 17, borderRadius: 12, marginBottom: 20 }}>
      <View style={[s.between, { marginBottom: 9 }]}><Text style={s.label}>时间与人物</Text><Chip label="本月" selected={thisMonth} onPress={() => setThisMonth(!thisMonth)} /></View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 5 }}><Chip label="所有人物" selected={person === "all"} onPress={() => setPerson("all")} />{data.people.map(p => <Chip key={p.id} label={hidden ? "人物" : p.name} selected={person === p.id} onPress={() => setPerson(p.id)} />)}</ScrollView>
    </View>}
    {!!followups.length && !filtered && <View style={{ backgroundColor: "#EDEFE9", borderRadius: 10, marginBottom: 26, paddingHorizontal: 16 }}>
      <Pressable accessibilityRole="button" accessibilityLabel="待跟进记录" accessibilityState={{ expanded }} onPress={() => setExpanded(!expanded)} style={[s.row, { minHeight: 55, gap: 10 }]}><Icon name="clock" size={17} color={c.muted} /><Text style={[s.label, { flex: 1 }]}>{followups.length} 个片刻待跟进</Text><Icon name={expanded ? "chevron-up" : "chevron-down"} size={17} color={c.muted} /></Pressable>
      {expanded && followups.map(e => <View key={e.id} style={[s.between, { paddingBottom: 10 }]}><Name value={data.people.find(p => p.id === e.personId)?.name || ""} /><Pressable accessibilityRole="button" accessibilityLabel="完成跟进" onPress={() => void complete(e.id)} style={{ minHeight: 44, justifyContent: "center" }}><Text style={[s.label, { color: c.blue }]}>标记完成</Text></Pressable></View>)}
    </View>}
    {filtered && <View style={[s.between, { marginBottom: 18 }]}><Text style={s.tiny}>{month === "all" ? "筛选结果" : month.replace("-", " / ")} · {entries.length} 条</Text><Pressable accessibilityRole="button" accessibilityLabel="重置筛选" onPress={() => { setQuery(""); setKind("all"); setPerson("all"); setThisMonth(false); router.setParams({ month: "" }); }} style={{ minHeight: 44, justifyContent: "center" }}><Text style={[s.tiny, { color: c.blue }]}>重置筛选</Text></Pressable></View>}
    {!entries.length ? <Empty title="还没有这一页" description="记下一个片刻，或调整筛选条件。" action="记一笔" onPress={() => router.push("/record")} icon="edit-3" /> : entries.map((entry, index) => {
      const p = data.people.find(p => p.id === entry.personId)!;
      const showMonth = index === 0 || entries[index - 1].date.slice(0, 7) !== entry.date.slice(0, 7);
      return <View key={entry.id}>
        {showMonth && <View style={[s.row, { alignItems: "baseline", gap: 10, marginBottom: 21, marginTop: index ? 18 : 0 }]}><Text style={{ fontSize: 30, lineHeight: 39, fontWeight: "300", color: c.ink }}>{Number(entry.date.slice(5, 7))} 月</Text><Text style={s.tiny}>{entry.date.slice(0, 4)}</Text><View style={{ height: 1, flex: 1, backgroundColor: c.line, marginLeft: 7 }} /></View>}
        <View style={{ flexDirection: "row", gap: 19 }}>
          <View style={{ width: 37, alignItems: "flex-start" }}><Text style={{ fontSize: 27, lineHeight: 32, fontWeight: "300", color: c.ink, fontVariant: ["tabular-nums"] }}>{entry.date.slice(8)}</Text><Text style={[s.tiny, { marginTop: 5 }]}>{["周日", "周一", "周二", "周三", "周四", "周五", "周六"][new Date(entry.date + "T12:00:00").getDay()]}</Text><View style={{ flex: 1, width: 1, backgroundColor: c.line, marginTop: 16, marginLeft: 12, marginBottom: 14 }} /></View>
          <View style={{ flex: 1, paddingBottom: 28 }}><Pressable accessibilityRole="button" accessibilityLabel={hidden ? "编辑私人记录" : `编辑记录：${entry.title}`} onPress={() => router.push({ pathname: "/record", params: { id: entry.id } })}>
            <View style={[s.row, { gap: 7, marginBottom: 10 }]}><Avatar uri={p.photo} name={p.name} hidden={hidden} size={22} /><Name value={p.name} style={s.label} /><View style={{ flex: 1 }} /><View style={{ width: 4, height: 4, borderRadius: 2, backgroundColor: entry.kind === "intimacy" ? c.blue : c.muted }} /><Text style={s.tiny}>{kindLabels[entry.kind]}</Text></View>
            <Text style={[s.h2, { fontSize: 18, lineHeight: 27 }]}>{hidden ? "私人记录" : entry.title}</Text>
            {!!entry.note && <Text numberOfLines={2} style={[s.muted, { marginTop: 7 }]}>{hidden ? "内容已隐藏" : entry.note}</Text>}
            <View style={[s.row, { gap: 5, marginTop: 12 }]}><Icon name="map-pin" size={11} color={c.muted} /><Text style={s.tiny}>{hidden ? "已隐藏" : entry.city || "地点待补充"}</Text></View>
          </Pressable>{entry.followUp && entry.completed && <Pressable accessibilityRole="button" accessibilityLabel="撤销跟进完成" onPress={() => void complete(entry.id)} style={{ minHeight: 44, justifyContent: "center" }}><Text style={[s.tiny, { color: c.green }]}>已跟进 · 撤销</Text></Pressable>}</View>
        </View>
      </View>;
    })}
  </Screen>;
}
