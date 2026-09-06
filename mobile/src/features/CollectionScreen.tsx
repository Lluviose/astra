import React, { useState } from "react";
import { View, Text, Pressable, ScrollView, useWindowDimensions } from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { collection, intimacyCount, personEntries } from "../domain/model";
import { Screen, Photo, Avatar, Icon, IconButton, Name, Empty, PageTitle, Segments, SearchField, SectionHeading, c, s } from "../design/ui";

export default function CollectionScreen() {
  const { data, hidden } = useApp();
  const [filter, setFilter] = useState("all"), [search, setSearch] = useState(""), [searching, setSearching] = useState(false);
  const { width } = useWindowDimensions();
  const people = collection(data).filter(p => (filter !== "favorite" || p.favorite) && (p.name + p.city + p.tags.join("")).includes(search));
  const featured = [...people].sort((a, b) => Number(b.favorite) - Number(a.favorite))[0];
  const latest = featured ? personEntries(data, featured.id)[0] : undefined;
  const openPerson = (id: string) => router.push({ pathname: "/person/[id]", params: { id } });
  return <Screen>
    <PageTitle title="后宫" subtitle="你珍藏的人，与相处的片刻" count={collection(data).length} />
    <View style={[s.row, { borderBottomWidth: 1, borderColor: c.line, marginBottom: 23, gap: 12 }]}>
      <View style={{ flex: 1 }}><Segments items={[["all", "全部收藏"], ["favorite", "偏爱"]]} value={filter} onChange={setFilter} /></View>
      <IconButton name="search" label="搜索收藏" active={searching} onPress={() => { setSearching(!searching); setSearch(""); }} />
      <IconButton name="users" label="人物名册" onPress={() => router.push("/roster")} />
    </View>
    {searching && <View style={{ marginBottom: 22 }}><SearchField label="搜索收藏" value={search} onChangeText={setSearch} placeholder="代号、城市或标签" /></View>}
    {!featured ? <Empty title={search || filter === "favorite" ? "没有匹配的收藏" : "第一份收藏，等你写下"} description={search || filter === "favorite" ? "试试其他关键词或筛选条件。" : "建立人物档案，记下亲密相处，她就会出现在这里。"} action="新建人物" onPress={() => router.push("/person/edit")} /> : <>
      <Pressable accessibilityRole="button" accessibilityLabel="打开精选人物档案" testID="featured-person" onPress={() => openPerson(featured.id)} style={{ flexDirection: "row", gap: width > 700 ? 32 : 19 }}>
        <Photo uri={featured.photo} name={featured.name} hidden={hidden} style={{ flex: 1.9, aspectRatio: width > 700 ? 1 : 0.7, borderRadius: 7 }} />
        <View style={{ flex: 1, paddingTop: 5, paddingBottom: 4 }}>
          <View style={[s.between, { marginBottom: 19 }]}><Text style={[s.tiny, { letterSpacing: 1 }]}>精选档案</Text><Text style={[s.tiny, { color: c.ink }]}>01</Text></View>
          <View style={{ width: 28, height: 1, backgroundColor: c.ink, marginBottom: 21 }} />
          <Name value={featured.name} style={{ fontSize: 30, lineHeight: 39, fontWeight: "500", letterSpacing: -1 }} />
          <Text style={[s.muted, { marginTop: 8 }]}>{hidden ? "已隐藏" : featured.city || "地点待补充"}</Text>
          <View style={{ gap: 5, marginTop: 20 }}>{!hidden && featured.tags.slice(0, 3).map(tag => <Text key={tag} style={s.tiny}>{tag}</Text>)}</View>
          <View style={{ flex: 1, minHeight: 20 }} />
          <View style={[s.row, { gap: 5, alignItems: "baseline" }]}><Text style={{ fontSize: 29, lineHeight: 36, color: c.ink, fontWeight: "300" }}>{intimacyCount(data, featured.id)}</Text><Text style={s.tiny}>次亲密</Text></View>
          <View style={[s.between, { marginTop: 16 }]}>
            <Icon name={featured.favorite ? "heart" : "bookmark"} size={17} color={c.muted} />
            <View style={{ width: 44, height: 44, backgroundColor: c.ink, borderRadius: 22, alignItems: "center", justifyContent: "center" }}><Icon name="arrow-up-right" size={20} color="#fff" /></View>
          </View>
        </View>
      </Pressable>
      {latest && <Pressable accessibilityRole="button" accessibilityLabel="查看最近片刻" onPress={() => router.push({ pathname: "/record", params: { id: latest.id } })} style={{ flexDirection: "row", gap: 19, paddingVertical: 23, borderBottomWidth: 1, borderColor: c.line }}>
        <View style={{ width: 48 }}><Text style={[s.tiny, { marginBottom: 2 }]}>最近相处</Text><Text style={[s.label, { fontVariant: ["tabular-nums"], fontSize: 14 }]}>{latest.date.slice(5).replace("-", ".")}</Text></View>
        <View style={{ flex: 1 }}><Text numberOfLines={2} style={[s.h2, { fontSize: 17, lineHeight: 25 }]}>{hidden ? "私人记录" : latest.title}</Text><Text numberOfLines={1} style={[s.muted, { marginTop: 5 }]}>{hidden ? "内容已隐藏" : latest.note || "为这次相处补几句话"}</Text></View>
        <Icon name="arrow-up-right" size={17} color={c.muted} />
      </Pressable>}
      <View style={{ marginTop: 25 }}><SectionHeading title="人物一览" action="完整名册" onPress={() => router.push("/roster")} />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 12 }}>
          {data.people.filter(p => p.id !== featured.id && !p.archived).map(p => <Pressable key={p.id} accessibilityRole="button" accessibilityLabel={`打开${hidden ? "人物" : p.name}档案`} onPress={() => openPerson(p.id)} style={{ width: 137, padding: 15, backgroundColor: c.paper, borderRadius: 10 }}>
            <Avatar uri={p.photo} name={p.name} hidden={hidden} size={38} /><Name value={p.name} style={[s.label, { marginTop: 17, fontSize: 15 }]} /><Text style={[s.tiny, { marginTop: 4 }]}>{hidden ? "已隐藏" : p.city}</Text>
          </Pressable>)}
          <Pressable accessibilityRole="button" accessibilityLabel="新建人物" onPress={() => router.push("/person/edit")} style={{ width: 97, justifyContent: "center", alignItems: "center", gap: 14, borderWidth: 1, borderColor: c.line, borderRadius: 10 }}><Icon name="plus" color={c.muted} /><Text style={s.tiny}>新人物</Text></Pressable>
        </ScrollView>
      </View>
    </>}
  </Screen>;
}
