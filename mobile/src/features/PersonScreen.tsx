import React, { useState } from "react";
import {
  View,
  Text,
  Pressable,
  useWindowDimensions,
  ScrollView,
} from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { useApp } from "../data/store";
import {
  personEntries,
  intimacyCount,
  scoreAverage,
  dimensions,
  kindLabels,
} from "../domain/model";
import {
  Screen,
  Photo,
  Icon,
  IconButton,
  Chip,
  Name,
  Button,
  Empty,
  SectionHeading,
  c,
  s,
} from "../design/ui";
import { LinearGradient } from "expo-linear-gradient";
import Radar from "../design/Radar";
import { Segments } from "../design/ui";
import { pickPhoto } from "../platform/media";

export default function PersonScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { data, hidden, mutate, notify } = useApp();
  const person = data.people.find((p) => p.id === id),
    [tab, setTab] = useState("story");
  const { width } = useWindowDimensions();
  if (!person)
    return (
      <Screen back title="人物档案">
        <Empty title="找不到这份档案" description="人物可能已被删除。" />
      </Screen>
    );
  const entries = personEntries(data, id);
  const edit = () => router.push({ pathname: "/person/edit", params: { id } });
  async function favorite() {
    try {
      await mutate((d) => ({
        ...d,
        people: d.people.map((p) =>
          p.id === id ? { ...p, favorite: !p.favorite } : p,
        ),
      }));
    } catch {
      notify("保存失败，请重试");
    }
  }
  async function addPhoto() {
    if (hidden) {
      notify("请先显示私人内容");
      return;
    }
    try {
      const photo = await pickPhoto();
      if (photo) {
        await mutate((d) => ({
          ...d,
          people: d.people.map((p) =>
            p.id === id ? { ...p, album: [...p.album, photo] } : p,
          ),
        }));
        notify("已加入私藏");
      }
    } catch (e) {
      notify(e instanceof Error ? e.message : "未能添加照片");
    }
  }
  return (
    <Screen
      back
      title="人物档案"
      right={<IconButton name="edit-3" label="编辑人物" onPress={edit} />}
    >
      <View style={{ borderRadius: 12, overflow: "hidden" }}>
        <Photo uri={person.photo} name={person.name} hidden={hidden} style={{ width: "100%", aspectRatio: width > 760 ? 2.2 : 1.5 }} />
        <LinearGradient colors={["transparent", "rgba(12,20,16,0.78)"]} style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 145 }} />
        <View style={{ position: "absolute", bottom: 21, left: 21, right: 21 }}>
          <Name value={person.name} style={{ color: "#fff", fontSize: 33, lineHeight: 44, fontWeight: "500" }} />
          <Text style={[s.tiny, { color: "#E7ECE7", marginTop: 3 }]}>{hidden ? "已隐藏" : [person.city, ...person.tags.slice(0, 2)].filter(Boolean).join("  ·  ")}{person.archived ? "  ·  已归档" : ""}</Text>
        </View>
        <IconButton name="heart" label={person.favorite ? "取消偏爱" : "设为偏爱"} active={person.favorite} onPress={() => void favorite()} style={{ position: "absolute", top: 13, right: 13, backgroundColor: "rgba(255,255,255,0.92)" }} />
      </View>
      <View style={{ flexDirection: "row", paddingVertical: 21 }}>
        {[[entries.length, "相处片刻"], [intimacyCount(data, id), "亲密记录"], [scoreAverage(person.scores).toFixed(1), "综合评分"]].map(([n, label], i) => <View key={label} style={{ flex: 1, paddingLeft: i ? 20 : 0, borderLeftWidth: i ? 1 : 0, borderColor: c.line }}><Text style={{ fontSize: 25, lineHeight: 32, fontWeight: "400", color: c.ink }}>{n}</Text><Text style={[s.tiny, { marginTop: 3 }]}>{label}</Text></View>)}
      </View>
      <Button icon="plus" onPress={() => router.push({ pathname: "/record", params: { personId: id } })}>记下这次相处</Button>
      <View style={{ marginTop: 17, marginBottom: 9, borderBottomWidth: 1, borderColor: c.line }}><Segments items={[["story", "战绩"], ["profile", "画像"], ["album", "私藏"]]} value={tab} onChange={setTab} /></View>
      {tab === "story" &&
        (entries.length ? (
          entries.map((e) => (
            <Pressable
              key={e.id}
              accessibilityRole="button"
              onPress={() =>
                router.push({ pathname: "/record", params: { id: e.id } })
              }
              style={{
                paddingVertical: 20,
                borderBottomWidth: 1,
                borderBottomColor: c.line,
              }}
            >
              <View style={s.between}>
                <Text style={s.tiny}>{e.date.replaceAll("-", " / ")}</Text>
                <Text style={[s.tiny, { color: c.blue }]}>
                  {kindLabels[e.kind]}
                </Text>
              </View>
              <Text style={[s.h2, { fontSize: 18, marginTop: 9 }]}>
                {hidden ? "私人记录" : e.title}
              </Text>
              <Text style={[s.muted, { marginTop: 7 }]}>
                {hidden ? "内容已隐藏" : e.note}
              </Text>
            </Pressable>
          ))
        ) : (
          <Empty title="下一次，从这里开始" description="还没有相处记录。" />
        ))}
      {tab === "profile" && <View style={{ paddingTop: 16 }}>
        <SectionHeading title="关于她" action="编辑" onPress={edit} />
        <Text style={[s.body, { lineHeight: 28, marginBottom: 28 }]}>{hidden ? "内容已隐藏" : person.note || "还没有写下关于她的印象。"}</Text>
        <View style={{ backgroundColor: c.paper, borderRadius: 13, padding: 19 }}>
          <View style={s.between}><Text style={s.label}>六维画像</Text><Pressable accessibilityRole="button" onPress={edit} style={{ minHeight: 44, justifyContent: "center" }}><Text style={[s.tiny, { color: c.blue }]}>调整评分 ↗</Text></Pressable></View>
          <View style={[s.row, { gap: 2 }]}><View style={{ flex: 1.8 }}><Radar scores={hidden ? [0,0,0,0,0,0] : person.scores} /></View><View style={{ flex: 0.6, alignItems: "flex-end" }}><Text style={{ fontSize: 35, lineHeight: 44, color: c.ink, fontWeight: "300", letterSpacing: -1 }}>{hidden ? "—" : scoreAverage(person.scores).toFixed(1)}</Text><Text style={[s.tiny, { marginTop: 6 }]}>综合评分</Text><View style={{ width: 22, height: 1, backgroundColor: c.line, marginVertical: 17 }} /><Text style={s.tiny}>满分 10</Text></View></View>
          <View style={{ flexDirection: "row", flexWrap: "wrap" }}>{dimensions.map((label, i) => <View key={label} style={[s.between, { width: "50%", paddingVertical: 10, paddingRight: 13, borderTopWidth: 1, borderColor: c.line }]}><Text style={s.tiny}>{label}</Text><Text style={s.label}>{hidden ? "—" : person.scores[i] || "未评分"}</Text></View>)}</View>
        </View>
      </View>}
      {tab === "album" && (
        <View>
          <SectionHeading
            title={`私藏 · ${person.album.length}`}
            action="添加照片"
            onPress={() => void addPhoto()}
          />
          {person.album.length ? (
            <View style={{ flexDirection: "row", gap: 12, flexWrap: "wrap" }}>
              {person.album.map((photo, i) => (
                <Pressable
                  key={`${photo}-${i}`}
                  accessibilityRole="button"
                  accessibilityLabel={`查看第${i + 1}张私藏`}
                  onPress={() =>
                    !hidden &&
                    router.push({
                      pathname: "/photo",
                      params: { id, index: String(i) },
                    })
                  }
                  style={{ width: person.album.length === 1 ? "100%" : width > 760 ? "31%" : "47%" }}
                >
                  <Photo
                    uri={photo}
                    name={person.name}
                    hidden={hidden}
                    style={{
                      width: "100%",
                      aspectRatio: person.album.length === 1 ? 1.25 : 0.85,
                      borderRadius: 7,
                    }}
                  />
                </Pressable>
              ))}
            </View>
          ) : (
            <Empty
              title="留一些画面给自己"
              description="把照片收进这份档案。"
              action="添加照片"
              onPress={() => void addPhoto()}
              icon="image"
            />
          )}
        </View>
      )}
    </Screen>
  );
}
