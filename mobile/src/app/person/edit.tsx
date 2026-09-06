import React, { useState } from "react";
import {
  View,
  Text,
  Pressable,
  ScrollView,
  Switch,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { useApp, newId } from "../../data/store";
import {
  upsertPerson,
  removePerson,
  localDate,
  dimensions,
  type Scores,
} from "../../domain/model";
import { pickPhoto } from "../../platform/media";
import {
  Screen,
  Photo,
  Field,
  Button,
  Chip,
  Icon,
  Empty,
  ErrorNote,
  c,
  s,
} from "../../design/ui";
import Confirm from "../../design/Confirm";

export default function PersonEditor() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { data, hidden, setHidden, mutate, notify } = useApp();
  const original = data.people.find((p) => p.id === id);
  const [name, setName] = useState(original?.name || ""),
    [city, setCity] = useState(original?.city || ""),
    [note, setNote] = useState(original?.note || ""),
    [tags, setTags] = useState(original?.tags.join("、") || "");
  const [photo, setPhoto] = useState<string | null>(original?.photo || null),
    [scores, setScores] = useState<Scores>(
      original?.scores || [0, 0, 0, 0, 0, 0],
    );
  const [showScores, setShowScores] = useState(false),
    [favorite, setFavorite] = useState(original?.favorite || false),
    [archived, setArchived] = useState(original?.archived || false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [deleting, setDeleting] = useState(false);
  async function choosePhoto() {
    try {
      const next = await pickPhoto();
      if (next) setPhoto(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : "无法添加照片");
    }
  }
  async function save() {
    setBusy(true);
    setError("");
    try {
      const person = {
        id: id || newId(),
        name,
        city,
        note,
        tags: [
          ...new Set(
            tags
              .split(/[、,，]/)
              .map((t) => t.trim())
              .filter(Boolean),
          ),
        ],
        photo,
        album: original?.album || [],
        scores,
        favorite,
        archived,
        createdAt: original?.createdAt || localDate(),
      };
      await mutate((d) => upsertPerson(d, person));
      notify("人物档案已保存");
      if (id) router.back();
      else
        router.replace({ pathname: "/person/[id]", params: { id: person.id } });
    } catch (e) {
      setError(e instanceof Error ? e.message : "保存失败，请重试");
    } finally {
      setBusy(false);
    }
  }
  async function remove() {
    setBusy(true);
    try {
      await mutate((d) => removePerson(d, id!));
      notify("人物及关联记录已删除");
      router.replace("/roster");
    } catch {
      setError("删除失败，请重试");
      setDeleting(false);
    } finally {
      setBusy(false);
    }
  }
  if (id && !original)
    return (
      <Screen back title="人物档案">
        <Empty title="人物不存在" description="档案可能已经删除。" />
      </Screen>
    );
  if (hidden)
    return (
      <Screen back title="人物档案">
        <Empty
          title="私人内容已隐藏"
          description="显示后即可编辑人物档案。"
          action="显示并继续"
          onPress={() => setHidden(false)}
          icon="eye-off"
        />
      </Screen>
    );
  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <Screen back title={id ? "编辑人物" : "新的人物"}>
        <View style={{ maxWidth: 640, width: "100%", alignSelf: "center" }}>
          <Text style={[s.title, { marginTop: 10, marginBottom: 25 }]}>
            {id ? "关于她的，一点一滴。" : "故事里的新名字。"}
          </Text>
          <ErrorNote message={error} />
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="选择人物封面"
            onPress={() => void choosePhoto()}
            style={[s.row, { gap: 18, marginBottom: 29 }]}
          >
            <Photo
              uri={photo}
              name={name}
              style={{ width: 84, height: 104, borderRadius: 12 }}
            />
            <View style={{ gap: 6 }}>
              <Text style={[s.label, { color: c.blue }]}>
                {photo ? "更换封面" : "添加封面"}
              </Text>
              <Text style={s.tiny}>选一张你想记住的照片</Text>
            </View>
            <Icon name="plus" color={c.blue} />
          </Pressable>
          <Field
            label="人物代号"
            value={name}
            onChangeText={setName}
            placeholder="怎么称呼她？"
          />
          <Field
            label="城市（可选）"
            value={city}
            onChangeText={setCity}
            placeholder="例如：杭州"
          />
          <Field
            label="标签（可选）"
            value={tags}
            onChangeText={setTags}
            placeholder="摄影、咖啡、慢热"
          />
          <Field
            label="关于她（可选）"
            value={note}
            onChangeText={setNote}
            placeholder="兴趣、印象，或只有你知道的小事。"
            multiline
          />
          <View style={[s.between, { marginBottom: 25 }]}>
            <Text style={s.body}>设为偏爱</Text>
            <Switch
              accessibilityLabel="设为偏爱"
              value={favorite}
              onValueChange={setFavorite}
              trackColor={{ true: c.blue }}
            />
          </View>
          <Pressable
            accessibilityRole="button"
            onPress={() => setShowScores(!showScores)}
            style={[
              s.between,
              {
                minHeight: 52,
                borderTopWidth: 1,
                borderBottomWidth: 1,
                borderColor: c.line,
                marginBottom: 22,
              },
            ]}
          >
            <Text style={s.label}>六维评分（可选）</Text>
            <Icon name={showScores ? "minus" : "plus"} size={18} />
          </Pressable>
          {showScores &&
            dimensions.map((label, index) => (
              <View key={label} style={{ marginBottom: 20 }}>
                <View style={s.between}>
                  <Text style={s.label}>{label}</Text>
                  <Text style={[s.label, { color: c.blue }]}>
                    {scores[index] === 0 ? "未评分" : scores[index]}
                  </Text>
                </View>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={{ gap: 3, marginTop: 9 }}
                >
                  {Array.from({ length: 11 }, (_, i) => (
                    <Chip
                      key={i}
                      label={String(i)}
                      selected={scores[index] === i}
                      onPress={() =>
                        setScores(
                          scores.map((n, j) => (j === index ? i : n)) as Scores,
                        )
                      }
                    />
                  ))}
                </ScrollView>
              </View>
            ))}
          {id && (
            <View style={[s.between, { marginBottom: 25 }]}>
              <View>
                <Text style={s.body}>归档人物</Text>
                <Text style={s.tiny}>保留已有收藏和战绩</Text>
              </View>
              <Switch
                accessibilityLabel="归档人物"
                value={archived}
                onValueChange={setArchived}
                trackColor={{ true: c.blue }}
              />
            </View>
          )}
          <Button onPress={() => void save()} disabled={busy}>
            {busy ? "正在保存…" : "保存档案"}
          </Button>
          {id && (
            <Pressable
              accessibilityRole="button"
              onPress={() => setDeleting(true)}
              style={{ padding: 20, alignItems: "center", minHeight: 52 }}
            >
              <Text style={[s.muted, { color: c.red }]}>删除人物</Text>
            </Pressable>
          )}
          <Confirm
            visible={deleting}
            title="删除这份档案？"
            message="人物和她的全部相处记录都会被删除。"
            onCancel={() => setDeleting(false)}
            onConfirm={() => void remove()}
            busy={busy}
          />
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
