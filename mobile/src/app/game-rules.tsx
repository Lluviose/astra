import React, { useMemo, useState } from "react";
import { View, Text } from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { buildCampaign, validateRules } from "../game/engine";
import {
  defaultRules,
  ruleLabels,
  type RuleKey,
  type Rules,
} from "../game/types";
import FormScreen from "../design/FormScreen";
import {
  PageTitle,
  Field,
  Button,
  FormSection,
  Screen,
  Empty,
  c,
  s,
} from "../design/ui";

export default function GameRulesScreen() {
  const { data, mutate, notify, hidden } = useApp();
  const [initial] = useState(() => JSON.stringify(data.game.rules));
  const [values, setValues] = useState(() =>
    Object.fromEntries(
      Object.entries(data.game.rules).map(([k, v]) => [k, String(v)]),
    ),
  );
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const parsed = useMemo(
    () =>
      Object.fromEntries(
        Object.entries(values).map(([k, v]) => [
          k,
          v.trim() === "" ? NaN : Number(v),
        ]),
      ) as Rules,
    [values],
  );
  const preview = useMemo(() => {
    try {
      return buildCampaign({
        ...data,
        game: { ...data.game, rules: validateRules(parsed) },
      });
    } catch {
      return null;
    }
  }, [data, parsed]);
  async function save() {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const rules = validateRules(parsed);
      await mutate((d) => ({ ...d, game: { ...d.game, rules } }));
      notify("积分规则已保存，山河已重算");
      router.back();
    } catch (e) {
      setError(e instanceof Error ? e.message : "保存失败");
    } finally {
      setBusy(false);
    }
  }
  if (hidden)
    return (
      <Screen back title="积分规则">
        <Empty title="私人规则已隐藏" description="显示私人内容后编辑。" />
      </Screen>
    );
  return (
    <FormScreen
      title="积分规则"
      saveLabel="保存并重算"
      onSave={() => void save()}
      busy={busy}
      error={error}
      dirty={JSON.stringify(parsed) !== initial}
    >
      <PageTitle
        title="由你定义星尘"
        subtitle="每项 0–1000，设为 0 即关闭。仅亲密记录参与积分。"
      />
      <View
        style={{
          padding: 18,
          backgroundColor: "#E8EDE3",
          borderRadius: 12,
          marginBottom: 25,
        }}
      >
        <Text style={[s.label, { color: c.green }]}>变更预览</Text>
        <Text style={[s.body, { marginTop: 8 }]}>
          {preview
            ? `${preview.totalXP} 总经验 · ${preview.balance} 可用星尘 · LV.${preview.level}`
            : "请输入有效整数以预览"}
        </Text>
        <Text style={[s.tiny, { marginTop: 8 }]}>
          规则会追溯重算全部记录。积分不足或扩张路径失效的建造会暂缓；恢复条件后自动恢复。
        </Text>
      </View>
      <FormSection number="01" title="记录、探索与偏好">
        {(Object.keys(defaultRules) as RuleKey[]).map((key) => (
          <Field
            key={key}
            label={ruleLabels[key]}
            value={values[key]}
            onChangeText={(v) => setValues((old) => ({ ...old, [key]: v }))}
            keyboardType="number-pad"
            placeholder="0"
          />
        ))}
      </FormSection>
      <Text style={[s.muted, { marginBottom: 20 }]}>
        标签在同一条记录内去重；不同记录可重复获得标签积分。新人物、新城市和新地点奖励只计首次。身体评分是本次记录中的个人偏好快照。无套积分为私人游戏规则，不是健康安全评分。
      </Text>
      <Button
        secondary
        onPress={() =>
          setValues(
            Object.fromEntries(
              Object.entries(defaultRules).map(([k, v]) => [k, String(v)]),
            ),
          )
        }
      >
        恢复默认规则
      </Button>
    </FormScreen>
  );
}
