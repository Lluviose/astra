import React from "react";
import { View, Text } from "react-native";
import { useApp } from "../data/store";
import { summary } from "../domain/model";
import FootprintMap from "../platform/FootprintMap";
import { Screen, Icon, Empty, PageTitle, SectionHeading, c, s } from "../design/ui";
export default function Footprints() {
  const { data, hidden } = useApp();
  const { cities } = summary(data);
  return <Screen back title="城市足迹">
    <PageTitle title="相遇的坐标" subtitle="每一站，都来自你留下的记录" count={cities.length} />
    {!cities.length ? <Empty title="还没有第一站" description="在相处记录中填写城市，足迹会自动出现在这里。" icon="compass" /> : <>
      {!hidden ? <FootprintMap cities={cities} /> : <View style={{ height: 280, backgroundColor: "#E7EBE5", borderRadius: 12, alignItems: "center", justifyContent: "center", gap: 13 }}><Icon name="eye-off" color={c.muted} /><Text style={s.muted}>城市位置已隐藏</Text></View>}
      <View style={{ marginTop: 27 }}><SectionHeading title="城市档案" />{cities.map((city, i) => {
        const entries = data.entries.filter(e => e.city === city).sort((a, b) => b.date.localeCompare(a.date));
        return <View key={city} style={[s.row, { gap: 17, paddingVertical: 20, borderTopWidth: 1, borderColor: c.line }]}><Text style={[s.tiny, { width: 20, fontVariant: ["tabular-nums"] }]}>{String(i + 1).padStart(2, "0")}</Text><View style={{ flex: 1 }}><Text style={[s.h2, { fontSize: 21 }]}>{hidden ? "已隐藏" : city}</Text><Text style={[s.tiny, { marginTop: 5 }]}>最近相处 {entries[0]?.date.replaceAll("-", ".") || "—"}</Text></View><View style={{ alignItems: "flex-end" }}><Text style={{ fontSize: 25, lineHeight: 32, fontWeight: "300", color: c.ink }}>{entries.length}</Text><Text style={s.tiny}>次相处</Text></View></View>;
      })}</View>
    </>}
  </Screen>;
}
