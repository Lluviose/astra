import React from "react";
import { View, Text, Pressable } from "react-native";
import { router } from "expo-router";
import Svg, { Path, Circle, Line } from "react-native-svg";
import { useApp } from "../data/store";
import { summary } from "../domain/model";
import { Screen, Icon, PageTitle, SectionHeading, c, s, type IconName } from "../design/ui";

export default function HallScreen() {
  const { data, hidden } = useApp();
  const stats = summary(data);
  const max = Math.max(1, ...stats.months.map(m => m.count));
  const points = stats.months.map((m, i) => ({ x: 320 / 12 + i * 320 / 6, y: 111 - m.count / max * 85 }));
  const line = points.map((p, i) => `${i ? "L" : "M"}${p.x},${p.y}`).join(" ");
  const milestones: [string, string, IconName, boolean][] = [
    ["初见", "留下第一条记录", "feather", data.entries.length > 0],
    ["续篇", "积累十次相处", "repeat", data.entries.length >= 10],
    ["远行", "在三个城市留下足迹", "compass", stats.cities.length >= 3],
    ["长篇", "记下三十次相处", "book-open", data.entries.length >= 30],
  ];
  const kinds = [["intimacy", "亲密", c.blue], ["date", "约会", "#879A91"], ["missed", "未发生", "#C8CDC8"]].map(([key, label, color]) => ({ label, color, count: data.entries.filter(e => e.kind === key).length }));
  return <Screen>
    <PageTitle title="殿堂" subtitle={hidden ? "私人内容已隐藏" : data.settings.title} />
    <View style={{ backgroundColor: c.paper, borderRadius: 15, padding: 23 }}>
      <View style={[s.between, { alignItems: "flex-start" }]}>
        <View><Text style={s.muted}>累计相处</Text><View style={[s.row, { alignItems: "baseline", gap: 9, marginTop: 5 }]}><Text style={{ fontSize: 67, lineHeight: 79, fontWeight: "200", color: c.ink, letterSpacing: -3, fontVariant: ["tabular-nums"] }}>{String(data.entries.length).padStart(2, "0")}</Text><Text style={s.tiny}>次</Text></View></View>
        <View style={{ alignItems: "flex-end", gap: 7, paddingTop: 3 }}><Icon name="activity" size={19} color={c.blue} /><Text style={s.tiny}>最近六个月</Text></View>
      </View>
      <View style={{ marginTop: 13 }}>
        <Svg width="100%" height={130} viewBox="0 0 320 130" accessible={false}>
          <Line x1="26.67" x2="293.33" y1="111" y2="111" stroke={c.line} />
          <Line x1="26.67" x2="293.33" y1="68" y2="68" stroke="#F0F1EE" strokeDasharray="3 5" />
          <Path d={`${line} L293.33,111 L26.67,111 Z`} fill="#EFF2FF" />
          <Path d={line} stroke={c.blue} strokeWidth="2" strokeLinejoin="round" fill="none" />
          {points.map((p, i) => <Circle key={i} cx={p.x} cy={p.y} r={i === 5 ? 4 : 2.5} fill={c.blue} stroke="#fff" strokeWidth="1.5" />)}
        </Svg>
        <View style={{ flexDirection: "row" }}>{stats.months.map(m => <Pressable key={m.key} accessibilityRole="button" accessibilityLabel={`${m.label}，${m.count}条记录`} onPress={() => router.push({ pathname: "/journal", params: { month: m.key } })} style={{ flex: 1, alignItems: "center", minHeight: 44, gap: 2 }}><Text style={[s.tiny, { color: c.ink }]}>{m.count}</Text><Text style={s.tiny}>{m.label}</Text></Pressable>)}</View>
      </View>
      <View style={{ flexDirection: "row", borderTopWidth: 1, borderColor: c.line, paddingTop: 20, marginTop: 14 }}>
        {[[stats.collectionCount, "收藏人物"], [stats.intimateCount, "亲密记录"], [stats.cities.length, "足迹城市"]].map(([n, label], i) => <View key={label} style={{ flex: 1, paddingLeft: i ? 18 : 0, borderLeftWidth: i ? 1 : 0, borderColor: c.line }}><Text style={{ fontSize: 25, lineHeight: 33, fontWeight: "400", color: c.ink }}>{n}</Text><Text style={[s.tiny, { marginTop: 4 }]}>{label}</Text></View>)}
      </View>
    </View>
    <View style={{ marginTop: 28 }}><SectionHeading title="相处的组成" />
      <View style={{ height: 6, flexDirection: "row", gap: 3, borderRadius: 3, overflow: "hidden", backgroundColor: c.line }}>{kinds.filter(k => k.count).map(k => <View key={k.label} style={{ flex: k.count, backgroundColor: k.color }} />)}</View>
      <View style={[s.row, { marginTop: 13, justifyContent: "space-between" }]}>{kinds.map(k => <View key={k.label} style={[s.row, { gap: 6 }]}><View style={{ width: 5, height: 5, borderRadius: 3, backgroundColor: k.color }} /><Text style={s.tiny}>{k.label}</Text><Text style={[s.label, { fontVariant: ["tabular-nums"] }]}>{k.count}</Text></View>)}</View>
    </View>
    <View style={{ marginTop: 31 }}><SectionHeading title="故事的里程碑" />
      {milestones.map(([title, desc, icon, active], i) => <View key={title} style={[s.row, { gap: 15, borderTopWidth: 1, borderColor: c.line, paddingVertical: 17 }]}>
        <View style={{ width: 42, height: 42, borderRadius: 21, borderWidth: 1, borderColor: active ? "#C7D0CA" : c.line, alignItems: "center", justifyContent: "center", backgroundColor: active ? "#EBEFEA" : "transparent" }}><Icon name={icon} size={18} color={active ? "#485F52" : c.muted} /></View>
        <View style={{ flex: 1 }}><Text style={s.label}>{title}</Text><Text style={[s.tiny, { marginTop: 4 }]}>{desc}</Text></View><Text style={[s.tiny, { color: active ? c.green : c.muted }]}>{active ? "已达成" : "未达成"}</Text>
      </View>)}
    </View>
    <View style={{ flexDirection: "row", gap: 12, marginTop: 26 }}>
      {[["偏爱排行", "查看六维评分", "bar-chart-2", "/ranking"], ["城市足迹", `${stats.cities.length} 座城市`, "map", "/footprints"]].map(([title, subtitle, icon, path]) => <Pressable key={path} accessibilityRole="button" accessibilityLabel={title} onPress={() => router.push(path as "/ranking" | "/footprints")} style={{ flex: 1, backgroundColor: path === "/ranking" ? c.ink : c.paper, borderRadius: 12, padding: 18 }}><View style={[s.between, { marginBottom: 21 }]}><Icon name={icon as IconName} size={20} color={path === "/ranking" ? "#fff" : c.ink} /><Icon name="arrow-up-right" size={15} color={path === "/ranking" ? "#AEB6C4" : c.muted} /></View><Text style={[s.label, { color: path === "/ranking" ? "#fff" : c.ink }]}>{title}</Text><Text style={[s.tiny, { marginTop: 5, color: path === "/ranking" ? "#AEB6C4" : c.muted }]}>{subtitle}</Text></Pressable>)}
    </View>
  </Screen>;
}
