import React from "react";
import { View, Text, Pressable } from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { scoreAverage } from "../domain/model";
import { Screen, Photo, Avatar, Name, Icon, Empty, PageTitle, c, s } from "../design/ui";
export default function Ranking() {
  const { data, hidden } = useApp();
  const people = [...data.people].filter(p => scoreAverage(p.scores) > 0).sort((a, b) => scoreAverage(b.scores) - scoreAverage(a.scores));
  const first = people[0];
  const open = (id: string) => router.push({ pathname: "/person/[id]", params: { id } });
  return <Screen back title="偏爱排行">
    <PageTitle title="偏爱，自有次序" subtitle="按你的六维综合评分排列" />
    {first ? <>
      <Pressable accessibilityRole="button" accessibilityLabel={`查看榜首${hidden ? "人物" : first.name}`} onPress={() => open(first.id)} style={{ backgroundColor: c.paper, borderRadius: 13, padding: 18, flexDirection: "row", gap: 22, marginBottom: 27 }}>
        <Photo uri={first.photo} name={first.name} hidden={hidden} style={{ width: "42%", minHeight: 215, borderRadius: 6 }} />
        <View style={{ flex: 1, paddingTop: 4 }}><View style={s.between}><Text style={[s.tiny, { letterSpacing: 2 }]}>01 / 偏爱</Text><Icon name="arrow-up-right" size={16} color={c.muted} /></View><Name value={first.name} style={[s.h2, { fontSize: 26, lineHeight: 36, marginTop: 20 }]} /><Text style={[s.tiny, { marginTop: 6 }]}>{hidden ? "已隐藏" : first.city}</Text><View style={{ flex: 1, minHeight: 15 }} /><Text style={{ color: c.ink, fontSize: 38, lineHeight: 47, fontWeight: "300", letterSpacing: -1 }}>{scoreAverage(first.scores).toFixed(1)}<Text style={s.tiny}> / 10</Text></Text></View>
      </Pressable>
      <View style={[s.between, { paddingBottom: 13 }]}><Text style={s.tiny}>人物</Text><Text style={s.tiny}>综合评分</Text></View>
      {people.slice(1).map((p, i) => <Pressable key={p.id} accessibilityRole="button" accessibilityLabel={`查看${hidden ? "人物" : p.name}评分`} onPress={() => open(p.id)} style={[s.row, { gap: 15, paddingVertical: 22, borderTopWidth: 1, borderColor: c.line }]}><Text style={[s.tiny, { width: 20, fontVariant: ["tabular-nums"] }]}>{String(i + 2).padStart(2, "0")}</Text><Avatar uri={p.photo} name={p.name} hidden={hidden} size={43} /><View style={{ flex: 1 }}><Name value={p.name} style={[s.label, { fontSize: 16 }]} /><Text numberOfLines={1} style={[s.tiny, { marginTop: 5 }]}>{hidden ? "已隐藏" : p.tags.join(" · ")}</Text></View><Text style={{ fontSize: 23, lineHeight: 30, fontWeight: "300", color: c.ink }}>{scoreAverage(p.scores).toFixed(1)}</Text></Pressable>)}
      <Text style={[s.tiny, { marginTop: 25, paddingTop: 18, borderTopWidth: 1, borderColor: c.line }]}>未评分的人物不参与排行。评分只代表你自己的感受。</Text>
    </> : <Empty title="偏爱，由你定义" description="为人物填写评分，私人排行就会出现在这里。" />}
  </Screen>;
}
