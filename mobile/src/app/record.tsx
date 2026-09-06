import React, { useState } from "react";
import {
  View,
  Text,
  ScrollView,
  Pressable,
  Switch,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { useApp, newId } from "../data/store";
import {
  upsertEntry,
  upsertPerson,
  localDate,
  type Entry,
  type Person,
} from "../domain/model";
import {
  Screen,
  Field,
  Button,
  Chip,
  Avatar,
  Name,
  Icon,
  Empty,
  ErrorNote,
  c,
  s,
} from "../design/ui";
import Confirm from "../design/Confirm";

export default function Record() {
  const { id, personId } = useLocalSearchParams<{
    id?: string;
    personId?: string;
  }>();
  const { data, mutate, notify, hidden, setHidden } = useApp();
  const existing = data.entries.find((e) => e.id === id);
  const activePeople = data.people.filter(
    (p) => !p.archived || p.id === existing?.personId,
  );
  const [person, setPerson] = useState(
    existing?.personId ||
      personId ||
      (activePeople.length === 1
        ? activePeople[0].id
        : activePeople.length === 0
          ? "new"
          : ""),
  );
  const [newName, setNewName] = useState(""),
    [kind, setKind] = useState<Entry["kind"]>(existing?.kind || "intimacy");
  const [title, setTitle] = useState(existing?.title || ""),
    [date, setDate] = useState(existing?.date || localDate());
  const [city, setCity] = useState(
    existing?.city || data.people.find((p) => p.id === personId)?.city || "",
  );
  const [note, setNote] = useState(existing?.note || ""),
    [protection, setProtection] = useState<Entry["protection"]>(
      existing?.protection || "unspecified",
    );
  const [followUp, setFollowUp] = useState(existing?.followUp || false),
    [details, setDetails] = useState(false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [deleting, setDeleting] = useState(false);
  async function save() {
    setError("");
    setBusy(true);
    try {
      const selectedId = person === "new" ? newId() : person;
      const entry: Entry = {
        id: existing?.id || newId(),
        personId: selectedId,
        date,
        kind,
        title,
        note,
        city,
        protection,
        followUp,
        completed: existing?.completed || false,
      };
      await mutate((d) => {
        let next = d;
        if (person === "new") {
          const p: Person = {
            id: selectedId,
            name: newName,
            city,
            note: "",
            tags: [],
            photo: null,
            album: [],
            favorite: false,
            archived: false,
            scores: [0, 0, 0, 0, 0, 0],
            createdAt: localDate(),
          };
          next = upsertPerson(next, p);
        }
        return upsertEntry(next, entry);
      });
      notify("这个片刻，已记下。");
      router.canGoBack() ? router.back() : router.replace("/journal");
    } catch (e) {
      setError(e instanceof Error ? e.message : "暂时无法保存，请重试");
    } finally {
      setBusy(false);
    }
  }
  async function remove() {
    setBusy(true);
    try {
      await mutate((d) => ({
        ...d,
        entries: d.entries.filter((e) => e.id !== id),
      }));
      notify("记录已删除");
      router.canGoBack() ? router.back() : router.replace("/journal");
    } catch {
      setError("未能删除，请重试");
      setDeleting(false);
    } finally {
      setBusy(false);
    }
  }
  if (id && !existing)
    return (
      <Screen back title="记录">
        <Empty title="记录不存在" description="这条记录可能已删除。" />
      </Screen>
    );
  if (hidden)
    return (
      <Screen back title="记录">
        <Empty
          title="私人内容已隐藏"
          description="显示后即可选择人物、编辑记录。"
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
      <Screen back title={existing ? "编辑片刻" : "新的片刻"}>
        <View style={{ maxWidth: 640, width: "100%", alignSelf: "center" }}>
          <Text style={[s.title, { marginTop: 10 }]}>把这一刻留下。</Text>
          <Text style={[s.muted, { marginTop: 8, marginBottom: 29 }]}>
            几句话，就够记住一次相处。
          </Text>
          <ErrorNote message={error} />
          <Text style={[s.label, { marginBottom: 13 }]}>和谁一起</Text>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ gap: 14, paddingBottom: 22 }}
          >
            {activePeople.map((p) => (
              <Pressable
                key={p.id}
                accessibilityRole="button"
                accessibilityLabel={`选择${p.name}`}
                accessibilityState={{ selected: person === p.id }}
                onPress={() => {
                  setPerson(p.id);
                  if (!city) setCity(p.city);
                }}
                style={{
                  alignItems: "center",
                  gap: 8,
                  padding: 6,
                  borderWidth: 2,
                  borderColor: person === p.id ? c.blue : "transparent",
                  borderRadius: 17,
                }}
              >
                <Avatar uri={p.photo} name={p.name} size={46} />
                <Text
                  style={[s.tiny, { color: person === p.id ? c.blue : c.ink }]}
                >
                  {p.name}
                </Text>
              </Pressable>
            ))}
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="新人物"
              onPress={() => setPerson("new")}
              style={{
                alignItems: "center",
                gap: 8,
                padding: 6,
                borderWidth: 2,
                borderColor: person === "new" ? c.blue : "transparent",
                borderRadius: 17,
              }}
            >
              <View
                style={{
                  width: 46,
                  height: 46,
                  backgroundColor: c.soft,
                  borderRadius: 23,
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Icon name="plus" />
              </View>
              <Text style={s.tiny}>新人物</Text>
            </Pressable>
          </ScrollView>
          {person === "new" && (
            <Field
              label="人物代号"
              value={newName}
              onChangeText={setNewName}
              placeholder="怎么称呼她？"
            />
          )}
          <Text style={[s.label, { marginBottom: 10 }]}>这次相处</Text>
          <View style={[s.row, { gap: 5, marginBottom: 23 }]}>
            {[
              ["intimacy", "亲密"],
              ["date", "约会"],
              ["missed", "未发生"],
            ].map(([key, label]) => (
              <Chip
                key={key}
                label={label}
                selected={kind === key}
                onPress={() => setKind(key as Entry["kind"])}
              />
            ))}
          </View>
          <Field
            label="片刻标题"
            value={title}
            onChangeText={setTitle}
            placeholder="例如：雨停之后，一起散步"
          />
          <View style={{ flexDirection: "row", gap: 14 }}>
            <View style={{ flex: 1 }}>
              <Field
                label="日期"
                value={date}
                onChangeText={setDate}
                placeholder="YYYY-MM-DD"
              />
            </View>
            <View style={{ flex: 1 }}>
              <Field
                label="城市（可选）"
                value={city}
                onChangeText={setCity}
                placeholder="留下足迹的地方"
              />
            </View>
          </View>
          <Field
            label="想记住的事（可选）"
            value={note}
            onChangeText={setNote}
            placeholder="那天的心情、聊过的话，或下次想一起做的事。"
            multiline
          />
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ expanded: details }}
            onPress={() => setDetails(!details)}
            style={[
              s.between,
              {
                minHeight: 52,
                borderTopWidth: 1,
                borderBottomWidth: 1,
                borderColor: c.line,
                marginBottom: 20,
              },
            ]}
          >
            <Text style={s.muted}>更多细节</Text>
            <Icon name={details ? "minus" : "plus"} size={17} color={c.muted} />
          </Pressable>
          {details && (
            <View>
              <Text style={[s.label, { marginBottom: 10 }]}>保护情况</Text>
              <ScrollView
                horizontal
                contentContainerStyle={{ gap: 5, marginBottom: 18 }}
              >
                {[
                  ["unspecified", "未记录"],
                  ["yes", "有保护"],
                  ["no", "无保护"],
                ].map(([key, label]) => (
                  <Chip
                    key={key}
                    label={label}
                    selected={protection === key}
                    onPress={() => setProtection(key as Entry["protection"])}
                  />
                ))}
              </ScrollView>
              <View style={[s.between, { marginBottom: 24 }]}>
                <Text style={s.body}>加入待跟进</Text>
                <Switch
                  accessibilityLabel="加入待跟进"
                  value={followUp}
                  onValueChange={setFollowUp}
                  trackColor={{ true: c.blue }}
                />
              </View>
            </View>
          )}
          <Button icon="check" onPress={() => void save()} disabled={busy}>
            {busy ? "正在保存…" : "保存片刻"}
          </Button>
          {existing && (
            <Pressable
              accessibilityRole="button"
              onPress={() => setDeleting(true)}
              style={{ alignItems: "center", padding: 20, minHeight: 52 }}
            >
              <Text style={[s.muted, { color: c.red }]}>删除这条记录</Text>
            </Pressable>
          )}
          <Confirm
            visible={deleting}
            title="删除这个片刻？"
            message="这条记录将从战绩和人物档案中移除。"
            onCancel={() => setDeleting(false)}
            onConfirm={() => void remove()}
            busy={busy}
          />
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
