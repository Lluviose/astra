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
  PageTitle,
  FormSection,
  IconButton,
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
      if (id) router.canGoBack() ? router.back() : router.replace({ pathname: "/person/[id]", params: { id } });
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
  return <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === "ios" ? "padding" : undefined}>
    <Screen back title="人物档案"><View style={{ maxWidth: 640, width: "100%", alignSelf: "center" }}>
      <PageTitle title={id ? "编辑档案" : "新建档案"} subtitle="先留下代号，其余可以慢慢补全" />
      <ErrorNote message={error} />
      <Pressable accessibilityRole="button" accessibilityLabel="选择人物封面" onPress={() => void choosePhoto()} style={[s.row, { gap: 21, backgroundColor: c.paper, padding: 17, borderRadius: 12, marginBottom: 29 }]}>
        <Photo uri={photo} name={name} style={{ width: 75, height: 95, borderRadius: 6 }} />
        <View style={{ flex: 1 }}><Text style={[s.h2, { fontSize: 19 }]}>{name || "一份新的档案"}</Text><Text style={[s.tiny, { marginTop: 5, marginBottom: 15 }]}>选一张想记住的照片</Text><Text style={[s.label, { color: c.blue }]}>{photo ? "更换封面" : "添加封面"} ↗</Text></View>
      </Pressable>
      <FormSection number="01" title="人物信息">
        <Field label="人物代号" value={name} onChangeText={setName} placeholder="怎么称呼她？" />
        <Field label="城市（可选）" value={city} onChangeText={setCity} placeholder="例如：杭州" />
        <Field label="标签（可选）" value={tags} onChangeText={setTags} placeholder="摄影、咖啡、慢热" />
      </FormSection>
      <FormSection number="02" title="你的印象">
        <Field label="关于她（可选）" value={note} onChangeText={setNote} placeholder="兴趣、第一印象，或相处中的小事。" multiline />
        <View style={[s.between, { minHeight: 53 }]}><View><Text style={s.body}>设为偏爱</Text><Text style={s.tiny}>在收藏中优先看到她</Text></View><Switch accessibilityLabel="设为偏爱" value={favorite} onValueChange={setFavorite} trackColor={{ true: c.ink }} /></View>
      </FormSection>
      <View style={{ backgroundColor: c.paper, borderRadius: 12, paddingHorizontal: 17, marginBottom: 25 }}>
        <Pressable accessibilityRole="button" accessibilityLabel="六维评分" accessibilityState={{ expanded: showScores }} onPress={() => setShowScores(!showScores)} style={[s.between, { minHeight: 60 }]}><View><Text style={s.label}>六维评分</Text><Text style={s.tiny}>可选 · 0 表示未评分</Text></View><Icon name={showScores ? "minus" : "plus"} size={18} /></Pressable>
        {showScores && dimensions.map((label, index) => <View key={label} style={[s.between, { minHeight: 65, borderTopWidth: 1, borderColor: c.line }]}><Text style={s.label}>{label}</Text><View style={[s.row, { gap: 8 }]}><IconButton name="minus" label={`降低${label}评分`} onPress={() => setScores(scores.map((n, j) => j === index ? Math.max(0, n - 1) : n) as Scores)} /><Text style={[s.label, { width: 27, textAlign: "center", color: c.blue }]}>{scores[index] || "—"}</Text><IconButton name="plus" label={`提高${label}评分`} onPress={() => setScores(scores.map((n, j) => j === index ? Math.min(10, n + 1) : n) as Scores)} /></View></View>)}
      </View>
      {id && <View style={[s.between, { marginBottom: 26, minHeight: 52 }]}><View><Text style={s.body}>归档人物</Text><Text style={s.tiny}>保留已有收藏和战绩</Text></View><Switch accessibilityLabel="归档人物" value={archived} onValueChange={setArchived} trackColor={{ true: c.ink }} /></View>}
      <Button onPress={() => void save()} disabled={busy}>{busy ? "正在保存…" : "保存档案"}</Button>
      {id && <Pressable accessibilityRole="button" accessibilityLabel="删除人物" onPress={() => setDeleting(true)} style={{ minHeight: 54, alignItems: "center", justifyContent: "center" }}><Text style={[s.muted, { color: c.red }]}>删除人物</Text></Pressable>}
      <Confirm visible={deleting} title="删除这份档案？" message="人物和她的全部相处记录都会被删除。" onCancel={() => setDeleting(false)} onConfirm={() => void remove()} busy={busy} />
    </View></Screen>
  </KeyboardAvoidingView>;
}
