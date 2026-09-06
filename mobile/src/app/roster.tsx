import React, { useState } from "react";
import { View, Text, TextInput, Pressable, ScrollView } from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { scoreAverage, intimacyCount } from "../domain/model";
import {
  Screen,
  Avatar,
  Name,
  Icon,
  IconButton,
  Chip,
  Empty,
  c,
  s,
} from "../design/ui";
export default function Roster() {
  const { data, hidden } = useApp();
  const [query, setQuery] = useState(""),
    [filter, setFilter] = useState("all"),
    [sort, setSort] = useState("recent");
  const people = data.people
    .filter(
      (p) =>
        (filter === "all" ||
          (filter === "favorite" && p.favorite) ||
          (filter === "archived" && p.archived)) &&
        (p.name + p.city + p.tags.join("")).includes(query),
    )
    .sort((a, b) =>
      sort === "score"
        ? scoreAverage(b.scores) - scoreAverage(a.scores)
        : b.createdAt.localeCompare(a.createdAt),
    );
  return (
    <Screen
      back
      title="人物名册"
      right={
        <IconButton
          name="plus"
          label="新建人物"
          onPress={() => router.push("/person/edit")}
        />
      }
    >
      <View style={{ marginTop: 12, marginBottom: 24 }}>
        <Text style={s.title}>故事里的人。</Text>
        <Text style={[s.muted, { marginTop: 7 }]}>
          {data.people.length} 位人物，独一无二的相遇。
        </Text>
      </View>
      <TextInput
        accessibilityLabel="搜索人物"
        placeholder="搜索代号、城市或标签"
        value={query}
        onChangeText={setQuery}
        style={[s.input, { marginBottom: 15 }]}
      />
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={{ gap: 4, marginBottom: 22 }}
      >
        {[
          ["all", "全部"],
          ["favorite", "偏爱"],
          ["archived", "已归档"],
        ].map(([key, label]) => (
          <Chip
            key={key}
            label={label}
            selected={filter === key}
            onPress={() => setFilter(key)}
          />
        ))}
        <Chip
          label="按评分"
          selected={sort === "score"}
          onPress={() => setSort(sort === "score" ? "recent" : "score")}
        />
      </ScrollView>
      {people.length ? (
        people.map((p) => (
          <Pressable
            key={p.id}
            accessibilityRole="button"
            accessibilityLabel={`打开${hidden ? "人物" : p.name}档案`}
            onPress={() =>
              router.push({ pathname: "/person/[id]", params: { id: p.id } })
            }
            style={[
              s.row,
              {
                gap: 15,
                paddingVertical: 20,
                borderBottomWidth: 1,
                borderBottomColor: c.line,
              },
            ]}
          >
            <Avatar uri={p.photo} name={p.name} hidden={hidden} size={58} />
            <View style={{ flex: 1, gap: 6 }}>
              <View style={[s.row, { gap: 7 }]}>
                <Name value={p.name} style={[s.h2, { fontSize: 18 }]} />
                {p.favorite && <Icon name="heart" size={13} color={c.blue} />}
              </View>
              <Text style={s.tiny}>
                {hidden ? "已隐藏" : p.city || "地点待补充"} ·{" "}
                {intimacyCount(data, p.id)} 次亲密
                {p.archived ? " · 已归档" : ""}
              </Text>
            </View>
            <Text style={[s.label, { color: c.blue }]}>
              {scoreAverage(p.scores).toFixed(1)}
            </Text>
            <Icon name="chevron-right" size={17} color={c.muted} />
          </Pressable>
        ))
      ) : (
        <Empty
          title="还没有匹配的人物"
          description="新建一份档案，或试试其他关键词。"
          action="新建人物"
          onPress={() => router.push("/person/edit")}
        />
      )}
    </Screen>
  );
}
