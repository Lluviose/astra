import React, { useState } from "react";
import { View, Text, Pressable, useWindowDimensions } from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { scoreAverage, intimacyCount } from "../domain/model";
import { Screen, Photo, Name, Icon, IconButton, Empty, PageTitle, Segments, SearchField, c, s } from "../design/ui";
export default function Roster() {
  const { data, hidden } = useApp();
  const { width } = useWindowDimensions();
  const [query, setQuery] = useState(""), [filter, setFilter] = useState("all"), [sort, setSort] = useState("recent");
  const people = data.people.filter(p => (filter === "all" || filter === "favorite" && p.favorite || filter === "archived" && p.archived) && (p.name + p.city + p.tags.join("")).includes(query)).sort((a, b) => sort === "score" ? scoreAverage(b.scores) - scoreAverage(a.scores) : b.createdAt.localeCompare(a.createdAt));
  return <Screen back title="人物名册" right={<IconButton name="plus" label="新建人物" onPress={() => router.push("/person/edit")} />}>
    <PageTitle title="所有人物" subtitle="每份档案，单独珍藏" count={data.people.length} />
    <SearchField label="搜索人物" value={query} onChangeText={setQuery} placeholder="代号、城市或标签" />
    <View style={[s.row, { gap: 12, marginTop: 11, marginBottom: 24, borderBottomWidth: 1, borderColor: c.line }]}><View style={{ flex: 1 }}><Segments items={[["all", "全部"], ["favorite", "偏爱"], ["archived", "已归档"]]} value={filter} onChange={setFilter} /></View><IconButton name="bar-chart-2" label="按评分排序" active={sort === "score"} onPress={() => setSort(sort === "score" ? "recent" : "score")} /></View>
    {people.length ? <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 17 }}>{people.map(p => <Pressable key={p.id} accessibilityRole="button" accessibilityLabel={`打开${hidden ? "人物" : p.name}档案`} onPress={() => router.push({ pathname: "/person/[id]", params: { id: p.id } })} style={{ width: width > 760 ? "31%" : "47%", marginBottom: 17 }}>
      <View><Photo uri={p.photo} name={p.name} hidden={hidden} style={{ width: "100%", aspectRatio: 0.94, borderRadius: 8 }} />{p.favorite && <View style={{ position: "absolute", top: 9, right: 9, width: 27, height: 27, borderRadius: 14, backgroundColor: "rgba(255,255,255,0.9)", alignItems: "center", justifyContent: "center" }}><Icon name="heart" size={13} /></View>}</View>
      <View style={[s.between, { marginTop: 12, gap: 5 }]}><Name value={p.name} style={[s.label, { fontSize: 17, flexShrink: 1 }]} /><Text style={[s.tiny, { color: c.muted }]}>{scoreAverage(p.scores) ? scoreAverage(p.scores).toFixed(1) : "—"}</Text></View>
      <Text numberOfLines={1} style={[s.tiny, { marginTop: 5 }]}>{hidden ? "已隐藏" : p.city || "地点待补充"} · {intimacyCount(data, p.id)} 次亲密{p.archived ? " · 已归档" : ""}</Text>
    </Pressable>)}</View> : <Empty title="没有匹配的人物" description="换个关键词，或建立新档案。" action="新建人物" onPress={() => router.push("/person/edit")} />}
  </Screen>;
}
