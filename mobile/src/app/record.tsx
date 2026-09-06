import React, { useMemo, useState } from "react";
import { View, Text, ScrollView, Pressable, Switch } from "react-native";
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
  PageTitle,
  FormSection,
  Segments,
  Field,
  Chip,
  Avatar,
  Icon,
  Empty,
  c,
  s,
} from "../design/ui";
import { buildCampaign, rewardForDraft, splitTags } from "../game/engine";
import { resolveCity } from "../game/geography";
import { ruleLabels } from "../game/types";
import Confirm from "../design/Confirm";
import FormScreen from "../design/FormScreen";

export default function Record() {
  const {
    id,
    personId,
    city: selectedCity,
  } = useLocalSearchParams<{
    city?: string;
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
    existing?.city ||
      selectedCity ||
      data.people.find((p) => p.id === personId)?.city ||
      "",
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
  const [venue, setVenue] = useState(existing?.details?.venue || "");
  const [positions, setPositions] = useState(
    existing?.details?.positions.join("，") || "",
  );
  const [playTags, setPlayTags] = useState(
    existing?.details?.playTags.join("，") || "",
  );
  const [physiqueTags, setPhysiqueTags] = useState(
    existing?.details?.physiqueTags.join("，") || "",
  );
  const [bodyRating, setBodyRating] = useState(
    String(existing?.details?.bodyRating ?? 0),
  );
  const entryDetails = {
    venue,
    positions: splitTags(positions),
    playTags: splitTags(playTags),
    physiqueTags: splitTags(physiqueTags),
    bodyRating: bodyRating.trim() ? Number(bodyRating) : NaN,
  };
  const draft = {
    person,
    newName,
    kind,
    title,
    date,
    city,
    note,
    protection,
    followUp,
    venue,
    positions,
    playTags,
    physiqueTags,
    bodyRating,
  };
  const draftReward = useMemo(() => {
    try {
      const draftPerson = person === "new" ? "draft-person" : person;
      const previewData =
        person === "new"
          ? {
              ...data,
              people: [
                ...data.people,
                {
                  id: draftPerson,
                  name: newName,
                  city,
                  note: "",
                  tags: [],
                  photo: null,
                  album: [],
                  favorite: false,
                  archived: false,
                  scores: [0, 0, 0, 0, 0, 0],
                  createdAt: date,
                } as Person,
              ],
            }
          : data;
      return rewardForDraft(previewData, {
        id: existing?.id || "draft-entry",
        personId: draftPerson,
        date,
        kind,
        title,
        note,
        city,
        protection,
        followUp,
        completed: false,
        details: entryDetails,
      });
    } catch {
      return undefined;
    }
  }, [data, JSON.stringify(draft)]);
  const [initialDraft] = useState(() => JSON.stringify(draft));
  async function save() {
    if (busy) return;
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
        details: entryDetails,
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
      const earned =
        buildCampaign(useApp.getState().data).rewards.find(
          (r) => r.entryId === entry.id,
        )?.points ?? 0;
      notify(`记录已保存 · 本次 ${earned} 星尘`);
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
    <FormScreen
      title="相处记录"
      saveLabel="保存片刻"
      error={error}
      busy={busy}
      dirty={JSON.stringify(draft) !== initialDraft}
      onSave={() => void save()}
    >
      <View style={{ maxWidth: 640, width: "100%", alignSelf: "center" }}>
        <PageTitle
          title={existing ? "编辑片刻" : "新的片刻"}
          subtitle="留下私密记录，让山河随你生长"
        />
        <FormSection number="01" title="和谁一起">
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ gap: 10, paddingBottom: 5 }}
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
                style={[
                  s.row,
                  {
                    gap: 10,
                    minHeight: 63,
                    paddingHorizontal: 13,
                    borderWidth: 1,
                    borderColor: person === p.id ? c.ink : c.line,
                    borderRadius: 10,
                    backgroundColor: c.paper,
                  },
                ]}
              >
                <Avatar uri={p.photo} name={p.name} size={33} />
                <Text style={s.label}>{p.name}</Text>
                {person === p.id && <Icon name="check" size={14} />}
              </Pressable>
            ))}
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="新人物"
              accessibilityState={{ selected: person === "new" }}
              onPress={() => setPerson("new")}
              style={{
                minWidth: 72,
                minHeight: 63,
                borderWidth: 1,
                borderColor: person === "new" ? c.ink : c.line,
                borderRadius: 10,
                alignItems: "center",
                justifyContent: "center",
                gap: 3,
              }}
            >
              <Icon name="plus" size={17} />
              <Text style={s.tiny}>新人物</Text>
            </Pressable>
          </ScrollView>
          {person === "new" && (
            <View style={{ marginTop: 17 }}>
              <Field
                label="人物代号"
                value={newName}
                onChangeText={setNewName}
                placeholder="怎么称呼她？"
              />
            </View>
          )}
        </FormSection>
        <FormSection number="02" title="这次相处">
          <View
            style={{
              marginTop: -7,
              marginBottom: 21,
              borderBottomWidth: 1,
              borderColor: c.line,
            }}
          >
            <Segments
              items={[
                ["intimacy", "亲密"],
                ["date", "约会"],
                ["missed", "未发生"],
              ]}
              value={kind}
              onChange={(value) => setKind(value as Entry["kind"])}
            />
          </View>
          <Field
            label="片刻标题"
            value={title}
            onChangeText={setTitle}
            placeholder="例如：雨停之后，一起散步"
          />
          <View style={{ flexDirection: "row", gap: 13 }}>
            <View style={{ flex: 1 }}>
              <Field
                label="日期"
                value={date}
                onChangeText={setDate}
                placeholder="YYYY-MM-DD"
                keyboardType="numbers-and-punctuation"
              />
            </View>
            <View style={{ flex: 1 }}>
              <Field
                label="城市（可选）"
                value={city}
                onChangeText={setCity}
                placeholder="相处的城市"
              />
            </View>
          </View>
          <Field
            label="想记住的事（可选）"
            value={note}
            onChangeText={setNote}
            placeholder="那天聊过的话、心情，或者下次想做的事。"
            multiline
          />
        </FormSection>
        {kind === "intimacy" && (
          <FormSection
            number="03"
            title="私人细节与星尘"
            caption="可选字段。使用逗号分隔标签；同条记录内重复标签只计一次。"
          >
            <Field
              label="地点代号"
              value={venue}
              onChangeText={setVenue}
              placeholder="如：江边住处（无需精确地址）"
            />
            <Field
              label="姿势标签"
              value={positions}
              onChangeText={setPositions}
              placeholder="输入你的标签，用逗号分隔"
            />
            <Field
              label="玩法标签"
              value={playTags}
              onChangeText={setPlayTags}
              placeholder="输入你的标签，用逗号分隔"
            />
            <Field
              label="身体特征标签"
              value={physiqueTags}
              onChangeText={setPhysiqueTags}
              placeholder="只保存在这次私人记录里"
            />
            <Field
              label="主观身体评分（0–10）"
              value={bodyRating}
              onChangeText={setBodyRating}
              placeholder="0 表示未评分"
              keyboardType="number-pad"
            />
            <Text style={[s.label, { marginBottom: 10 }]}>防护情况</Text>
            <View
              style={[s.row, { gap: 5, flexWrap: "wrap", marginBottom: 18 }]}
            >
              {[
                ["unspecified", "未记录"],
                ["yes", "有套"],
                ["no", "无套"],
              ].map(([key, label]) => (
                <Chip
                  key={key}
                  label={label}
                  selected={protection === key}
                  onPress={() => setProtection(key as Entry["protection"])}
                />
              ))}
            </View>
            <View
              style={{
                padding: 18,
                borderRadius: 12,
                backgroundColor: "#E8EDE3",
              }}
            >
              <Text style={[s.h2, { color: c.green }]}>
                本次 {draftReward?.points ?? 0} 星尘
              </Text>
              <Text style={[s.tiny, { marginTop: 8 }]}>
                {draftReward?.lines
                  .filter((l) => l.points > 0)
                  .map((l) => `${ruleLabels[l.key]} +${l.points}`)
                  .join(" · ") || "选择人物并填写有效信息后预览积分"}
              </Text>
              {!!city && !resolveCity(city) && (
                <Text style={[s.tiny, { marginTop: 8 }]}>
                  城市未匹配到大陆沙盘，仍可保存并获得记录积分。
                </Text>
              )}
              <Text style={[s.tiny, { marginTop: 8 }]}>
                保存后重新计算。身体评分仅代表个人偏好，防护积分不代表健康安全评价。
              </Text>
            </View>
          </FormSection>
        )}
        <View
          style={{
            backgroundColor: c.paper,
            borderRadius: 12,
            paddingHorizontal: 17,
            marginTop: -14,
            marginBottom: 25,
          }}
        >
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="更多细节"
            accessibilityState={{ expanded: details }}
            onPress={() => setDetails(!details)}
            style={[s.between, { minHeight: 58 }]}
          >
            <View>
              <Text style={s.label}>更多细节</Text>
              <Text style={s.tiny}>后续跟进</Text>
            </View>
            <Icon name={details ? "minus" : "plus"} size={18} />
          </Pressable>
          {details && (
            <View
              style={{
                paddingTop: 13,
                paddingBottom: 14,
                borderTopWidth: 1,
                borderColor: c.line,
              }}
            >
              <View style={[s.between, { minHeight: 50 }]}>
                <Text style={s.body}>加入待跟进</Text>
                <Switch
                  accessibilityLabel="加入待跟进"
                  value={followUp}
                  onValueChange={setFollowUp}
                  trackColor={{ true: c.ink }}
                />
              </View>
            </View>
          )}
        </View>
        {existing && (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="删除这条记录"
            onPress={() => setDeleting(true)}
            style={{ alignItems: "center", padding: 20, minHeight: 52 }}
          >
            <Text style={[s.muted, { color: c.red }]}>删除这条记录</Text>
          </Pressable>
        )}
        <Confirm
          visible={deleting}
          title="删除这条记录？"
          message="这条记录将从战绩和人物档案中移除。"
          onCancel={() => setDeleting(false)}
          onConfirm={() => void remove()}
          busy={busy}
        />
      </View>
    </FormScreen>
  );
}
