import React, { useMemo, useState } from "react";
import { View, Text, Pressable } from "react-native";
import { router } from "expo-router";
import { useApp } from "../../data/store";
import { buildCampaign, levelNames } from "../../game/engine";
import { biomeLabels } from "../../game/geography";
import {
  Screen,
  PageTitle,
  Empty,
  Icon,
  SearchField,
  c,
  s,
} from "../../design/ui";

export default function CodexScreen() {
  const { data, hidden } = useApp();
  const campaign = useMemo(() => buildCampaign(data), [data]);
  const [query, setQuery] = useState("");
  if (hidden)
    return (
      <Screen title="成就">
        <Empty title="图鉴已隐藏" description="显示私人内容后查看进度。" />
      </Screen>
    );
  return (
    <Screen title="建筑与成就">
      <PageTitle
        title="山河藏卷"
        subtitle={`${campaign.achievements.filter((a) => a.unlocked).length} 项成就 · ${campaign.cities.filter((p) => p.level > 0).length} 座建筑已解锁`}
      />
      <View
        style={{
          backgroundColor: "#163D35",
          borderRadius: 16,
          padding: 22,
          marginBottom: 25,
        }}
      >
        <Icon name="award" color="#DAB477" size={28} />
        <Text style={{ fontSize: 25, color: "#E3D2AC", marginTop: 15 }}>
          {campaign.rank} · LV.{campaign.level}
        </Text>
        <Text style={{ color: "#AAC2B5", marginTop: 10, lineHeight: 22 }}>
          人物外观随等级变化：旅人 → 筑城者 → 领主 →
          君主。沙盘地色会随你的领地和阶段生长。
        </Text>
      </View>
      <Text style={[s.h2, { marginBottom: 12 }]}>成就长卷</Text>
      {campaign.achievements.map((a) => (
        <View
          key={a.id}
          style={[
            s.row,
            {
              gap: 15,
              paddingVertical: 17,
              borderBottomWidth: 1,
              borderColor: c.line,
            },
          ]}
        >
          <View
            style={{
              width: 44,
              height: 44,
              alignItems: "center",
              justifyContent: "center",
              borderRadius: 12,
              backgroundColor: a.unlocked ? "#E4EBDF" : "#EDEEE9",
            }}
          >
            <Icon
              name={a.unlocked ? "award" : "lock"}
              color={a.unlocked ? c.green : c.muted}
            />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={s.label}>{a.title}</Text>
            <Text style={[s.tiny, { marginTop: 4 }]}>{a.detail}</Text>
          </View>
          <Text style={s.tiny}>
            {Math.min(a.progress, a.target)}/{a.target}
          </Text>
        </View>
      ))}
      <View style={[s.between, { marginTop: 30, marginBottom: 15 }]}>
        <Text style={s.h2}>城市建筑图鉴</Text>
        <Text style={s.tiny}>四阶段 / 每城独立</Text>
      </View>
      <SearchField
        label="搜索建筑图鉴"
        value={query}
        onChangeText={setQuery}
        placeholder="城市或建筑名称"
      />
      <View style={{ marginTop: 15, gap: 12 }}>
        {campaign.cities
          .filter((p) =>
            !query
              ? p.visits > 0 || p.level > 0
              : `${p.city.name}${p.city.landmark}`.includes(query),
          )
          .map((p) => (
            <View
              key={p.city.id}
              style={{
                backgroundColor: c.paper,
                padding: 18,
                borderRadius: 14,
                borderWidth: 1,
                borderColor: c.line,
              }}
            >
              <View style={[s.between, { gap: 10 }]}>
                <View style={{ flex: 1 }}>
                  <Text style={s.h2}>{p.city.landmark}</Text>
                  <Text style={[s.tiny, { marginTop: 6 }]}>
                    {p.city.name} · {biomeLabels[p.city.biome]} ·{" "}
                    {levelNames[p.level]}
                  </Text>
                </View>
                <Icon
                  name={p.level === 4 ? "award" : p.level ? "box" : "lock"}
                  color={p.level ? c.green : c.muted}
                />
              </View>
              <View style={[s.row, { gap: 6, marginTop: 15 }]}>
                {[1, 2, 3, 4].map((l) => (
                  <View
                    key={l}
                    style={{
                      flex: 1,
                      height: 5,
                      borderRadius: 2,
                      backgroundColor: p.level >= l ? "#8FAF92" : "#E7EAE2",
                    }}
                  />
                ))}
              </View>
            </View>
          ))}
      </View>
      {!campaign.cities.some((p) => p.visits || p.level) && !query && (
        <Empty
          title="第一座建筑，等你点亮"
          description="去山河记录一次，再用星尘攻占城市。搜索可以查看尚未解锁的建筑。"
        />
      )}
      <View style={[s.row, { gap: 12, marginTop: 25 }]}>
        {[
          ["/ranking", "偏爱排行"],
          ["/footprints", "城市足迹"],
        ].map(([path, label]) => (
          <Pressable
            key={path}
            accessibilityRole="button"
            accessibilityLabel={label}
            onPress={() => router.push(path as "/ranking" | "/footprints")}
            style={{
              flex: 1,
              minHeight: 52,
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: c.paper,
              borderRadius: 12,
            }}
          >
            <Text style={s.label}>{label}</Text>
          </Pressable>
        ))}
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="查看积分规则"
        onPress={() => router.push("/game-rules")}
        style={[s.between, { minHeight: 60, marginTop: 20 }]}
      >
        <Text style={s.label}>查看与调整积分规则</Text>
        <Icon name="arrow-up-right" size={18} />
      </Pressable>
    </Screen>
  );
}
