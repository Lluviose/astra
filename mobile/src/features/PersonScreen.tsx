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
      <View
        style={{
          flexDirection: width > 760 ? "row" : "column",
          gap: width > 760 ? 35 : 0,
        }}
      >
        <Photo
          uri={person.photo}
          name={person.name}
          hidden={hidden}
          style={{
            width: width > 760 ? "48%" : "100%",
            aspectRatio: 1.1,
            borderRadius: 18,
          }}
        />
        <View style={{ flex: 1, marginTop: width > 760 ? 10 : 22 }}>
          <View style={s.between}>
            <Name value={person.name} style={s.title} />
            <IconButton
              name="heart"
              label={person.favorite ? "取消偏爱" : "设为偏爱"}
              active={person.favorite}
              onPress={() => void favorite()}
            />
          </View>
          <View style={[s.row, { gap: 5, marginTop: 8 }]}>
            <Icon name="map-pin" size={14} color={c.muted} />
            <Text style={s.muted}>
              {hidden ? "已隐藏" : person.city || "地点待补充"}
            </Text>
            {person.archived && <Text style={s.muted}> · 已归档</Text>}
          </View>
          <View
            style={{
              flexDirection: "row",
              gap: 9,
              marginTop: 15,
              flexWrap: "wrap",
            }}
          >
            {!hidden &&
              person.tags.map((tag) => (
                <Text
                  key={tag}
                  style={[
                    s.tiny,
                    {
                      backgroundColor: "#ECEFF4",
                      paddingHorizontal: 11,
                      paddingVertical: 6,
                      borderRadius: 6,
                    },
                  ]}
                >
                  {tag}
                </Text>
              ))}
          </View>
          <View
            style={{
              flexDirection: "row",
              marginTop: 25,
              paddingVertical: 20,
              borderTopWidth: 1,
              borderBottomWidth: 1,
              borderColor: c.line,
            }}
          >
            {[
              [entries.length, "相处片刻"],
              [intimacyCount(data, id), "亲密记录"],
              [scoreAverage(person.scores).toFixed(1), "综合评分"],
            ].map(([n, label]) => (
              <View key={label} style={{ flex: 1, gap: 5 }}>
                <Text style={[s.h2, { fontSize: 25 }]}>{n}</Text>
                <Text style={s.tiny}>{label}</Text>
              </View>
            ))}
          </View>
          <Button
            icon="plus"
            onPress={() =>
              router.push({ pathname: "/record", params: { personId: id } })
            }
            style={{ marginTop: 20 }}
          >
            记下这次相处
          </Button>
        </View>
      </View>
      <View style={[s.row, { gap: 3, marginTop: 29, marginBottom: 23 }]}>
        {[
          ["story", "战绩"],
          ["profile", "画像"],
          ["album", "私藏"],
        ].map(([key, label]) => (
          <Chip
            key={key}
            label={label}
            selected={tab === key}
            onPress={() => setTab(key)}
          />
        ))}
      </View>
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
      {tab === "profile" && (
        <View>
          <SectionHeading title="关于她" action="编辑" onPress={edit} />
          <Text style={[s.body, { lineHeight: 27, marginBottom: 30 }]}>
            {hidden ? "内容已隐藏" : person.note || "还没有写下关于她的印象。"}
          </Text>
          <SectionHeading
            title="你的六维画像"
            action="调整评分"
            onPress={edit}
          />
          {dimensions.map((label, i) => (
            <View key={label} style={[s.row, { gap: 18, marginBottom: 21 }]}>
              <Text style={[s.muted, { width: 35 }]}>{label}</Text>
              <View
                style={{
                  flex: 1,
                  height: 5,
                  borderRadius: 3,
                  backgroundColor: "#E4E9F2",
                }}
              >
                <View
                  style={{
                    width: `${person.scores[i] * 10}%`,
                    height: 5,
                    borderRadius: 3,
                    backgroundColor: c.blue,
                  }}
                />
              </View>
              <Text style={[s.label, { width: 22 }]}>{person.scores[i]}</Text>
            </View>
          ))}
        </View>
      )}
      {tab === "album" && (
        <View>
          <SectionHeading
            title={`${person.album.length} 张私藏`}
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
                  style={{ width: width > 760 ? "31%" : "47%" }}
                >
                  <Photo
                    uri={photo}
                    name={person.name}
                    hidden={hidden}
                    style={{
                      width: "100%",
                      aspectRatio: 0.85,
                      borderRadius: 12,
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
