import React, { useState } from "react";
import {
  View,
  Text,
  Pressable,
  ScrollView,
  useWindowDimensions,
  TextInput,
} from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { collection, intimacyCount, personEntries } from "../domain/model";
import {
  Screen,
  Photo,
  Avatar,
  Icon,
  IconButton,
  Chip,
  Name,
  Empty,
  SectionHeading,
  c,
  s,
} from "../design/ui";

export default function CollectionScreen() {
  const data = useApp((a) => a.data),
    hidden = useApp((a) => a.hidden);
  const [filter, setFilter] = useState("all"),
    [search, setSearch] = useState(""),
    [searching, setSearching] = useState(false);
  const { width } = useWindowDimensions(),
    wide = width > 760;
  const people = collection(data).filter(
    (p) =>
      (filter !== "favorite" || p.favorite) &&
      (p.name + p.city + p.tags.join("")).includes(search),
  );
  const featured = [...people].sort(
    (a, b) => Number(b.favorite) - Number(a.favorite),
  )[0];
  const latest = featured ? personEntries(data, featured.id)[0] : undefined;
  const openPerson = (id: string) =>
    router.push({ pathname: "/person/[id]", params: { id } });
  return (
    <Screen>
      <View style={[s.between, { marginTop: 14, marginBottom: 23 }]}>
        <View style={{ flex: 1, paddingRight: 12 }}>
          <Text style={s.title}>心动，值得私藏。</Text>
          <Text style={[s.muted, { marginTop: 7 }]}>
            你的后宫 · {collection(data).length} 位人物
          </Text>
        </View>
        <IconButton
          name="search"
          label="搜索收藏"
          active={searching}
          onPress={() => {
            setSearching(!searching);
            setSearch("");
          }}
        />
      </View>
      {searching && (
        <TextInput
          accessibilityLabel="搜索收藏"
          placeholder="搜索代号、城市或标签"
          value={search}
          onChangeText={setSearch}
          style={[s.input, { marginBottom: 16 }]}
          autoFocus
        />
      )}
      <View style={[s.between, { marginBottom: 22 }]}>
        <View style={[s.row, { gap: 3 }]}>
          <Chip
            label="全部收藏"
            selected={filter === "all"}
            onPress={() => setFilter("all")}
          />
          <Chip
            label="偏爱"
            selected={filter === "favorite"}
            onPress={() => setFilter("favorite")}
          />
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push("/roster")}
          style={[s.row, { minHeight: 44, gap: 5 }]}
        >
          <Text style={s.muted}>名册</Text>
          <Icon name="arrow-up-right" size={15} color={c.muted} />
        </Pressable>
      </View>
      {!featured ? (
        <Empty
          title={
            search || filter === "favorite"
              ? "暂时没有匹配的人物"
              : "让故事从这里开始"
          }
          description={
            search || filter === "favorite"
              ? "试试其他筛选条件。"
              : "建立人物档案，记录一次亲密相处，她就会出现在你的收藏里。"
          }
          action="新建人物"
          onPress={() => router.push("/person/edit")}
        />
      ) : (
        <>
          <View
            style={{
              flexDirection: wide ? "row" : "column",
              gap: wide ? 34 : 0,
            }}
          >
            <View style={{ flex: wide ? 1.3 : undefined }}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="打开精选人物档案"
                testID="featured-person"
                onPress={() => openPerson(featured.id)}
              >
                <Photo
                  uri={featured.photo}
                  name={featured.name}
                  hidden={hidden}
                  style={{
                    width: "100%",
                    aspectRatio: wide ? 1.2 : 1.08,
                    borderRadius: 18,
                  }}
                />
                <View
                  style={{
                    position: "absolute",
                    top: 16,
                    left: 16,
                    backgroundColor: "rgba(255,255,255,0.93)",
                    borderRadius: 20,
                    paddingHorizontal: 12,
                    paddingVertical: 7,
                    flexDirection: "row",
                    gap: 6,
                    alignItems: "center",
                  }}
                >
                  <View
                    style={{
                      width: 5,
                      height: 5,
                      borderRadius: 3,
                      backgroundColor: c.blue,
                    }}
                  />
                  <Text style={[s.tiny, { color: c.ink, fontWeight: "600" }]}>
                    今日回味
                  </Text>
                </View>
                <View
                  style={{
                    position: "absolute",
                    right: 16,
                    bottom: 16,
                    backgroundColor: "#fff",
                    borderRadius: 24,
                    width: 44,
                    height: 44,
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Icon name="arrow-up-right" />
                </View>
              </Pressable>
              <View style={[s.between, { paddingTop: 17 }]}>
                <View style={[s.row, { gap: 10 }]}>
                  <Name
                    value={featured.name}
                    style={{ fontSize: 24, lineHeight: 32, fontWeight: "600" }}
                  />
                  {featured.favorite && (
                    <Icon name="heart" size={15} color={c.blue} />
                  )}
                </View>
                <Text style={s.muted}>
                  {hidden ? "已隐藏" : featured.city || "地点待补充"} ·{" "}
                  {intimacyCount(data, featured.id)} 次亲密
                </Text>
              </View>
              <Text style={[s.muted, { marginTop: 4 }]}>
                {hidden ? "私人内容已隐藏" : featured.tags.join(" / ")}
              </Text>
            </View>
            <View
              style={{ flex: wide ? 1 : undefined, marginTop: wide ? 0 : 28 }}
            >
              <SectionHeading
                title="最近的片刻"
                action="查看战绩"
                onPress={() => router.push("/journal")}
              />
              {latest && (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="查看最近片刻"
                  onPress={() =>
                    router.push({
                      pathname: "/record",
                      params: { id: latest.id },
                    })
                  }
                  style={{
                    borderLeftWidth: 2,
                    borderLeftColor: c.blue,
                    paddingLeft: 17,
                    paddingVertical: 3,
                  }}
                >
                  <Text style={s.tiny}>
                    {latest.date.replaceAll("-", " / ")}
                  </Text>
                  <Text style={[s.h2, { fontSize: 18, marginTop: 9 }]}>
                    {hidden ? "私人记录" : latest.title}
                  </Text>
                  <Text numberOfLines={3} style={[s.muted, { marginTop: 8 }]}>
                    {hidden
                      ? "内容已隐藏"
                      : latest.note || "留下一些文字，记住这个片刻。"}
                  </Text>
                </Pressable>
              )}
              <View
                style={{
                  marginTop: 28,
                  paddingVertical: 17,
                  borderTopWidth: 1,
                  borderBottomWidth: 1,
                  borderColor: c.line,
                  flexDirection: "row",
                  justifyContent: "space-between",
                }}
              >
                <Text style={s.muted}>相识至今</Text>
                <Text style={s.label}>
                  {featured.createdAt.replaceAll("-", " / ")}
                </Text>
              </View>
            </View>
          </View>
          <View style={s.section}>
            <SectionHeading
              title="也想再见"
              action="全部人物"
              onPress={() => router.push("/roster")}
            />
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ gap: 26, paddingBottom: 6 }}
            >
              {data.people
                .filter((p) => p.id !== featured.id && !p.archived)
                .map((p) => (
                  <Pressable
                    key={p.id}
                    accessibilityRole="button"
                    accessibilityLabel={`打开${hidden ? "人物" : p.name}档案`}
                    onPress={() => openPerson(p.id)}
                    style={{ alignItems: "center", gap: 9, minWidth: 65 }}
                  >
                    <Avatar
                      uri={p.photo}
                      name={p.name}
                      hidden={hidden}
                      size={60}
                    />
                    <Name value={p.name} style={s.label} />
                    <Text style={s.tiny}>{hidden ? "·" : p.city}</Text>
                  </Pressable>
                ))}
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="新建人物"
                onPress={() => router.push("/person/edit")}
                style={{ alignItems: "center", gap: 9, minWidth: 65 }}
              >
                <View
                  style={{
                    width: 60,
                    height: 60,
                    borderRadius: 30,
                    borderWidth: 1,
                    borderStyle: "dashed",
                    borderColor: "#BEC5D2",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Icon name="plus" color={c.muted} />
                </View>
                <Text style={s.muted}>新人物</Text>
              </Pressable>
            </ScrollView>
          </View>
        </>
      )}
    </Screen>
  );
}
