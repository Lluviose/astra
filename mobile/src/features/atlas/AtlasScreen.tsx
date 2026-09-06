import React, { useMemo, useState } from "react";
import { View, Text, Pressable, ScrollView } from "react-native";
import { router } from "expo-router";
import { useApp, newId } from "../../data/store";
import {
  Screen,
  Icon,
  Button,
  SearchField,
  Empty,
  ErrorNote,
  c,
  s,
} from "../../design/ui";
import {
  buildCampaign,
  canReach,
  invest,
  levelCost,
  levelNames,
} from "../../game/engine";
import { biomeLabels } from "../../game/geography";
import type { WorldView } from "../../game/types";
import WorldPanel from "./WorldPanel";

export default function AtlasScreen() {
  const { data, mutate, notify, hidden, setHidden } = useApp();
  const campaign = useMemo(() => buildCampaign(data), [data]);
  const [selected, setSelected] = useState(
    () => campaign.cities.find((p) => p.visits > 0)?.city.id ?? "310000",
  );
  const [query, setQuery] = useState(""),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const current = campaign.cities.find((p) => p.city.id === selected)!;
  const owned = campaign.cities.filter((p) => p.level > 0).length;
  const visited = campaign.cities.filter((p) => p.visits > 0).length;
  // Explicit privacy boundary. Do not pass Campaign, Data, or entries into the renderer.
  const world: WorldView = useMemo(
    () => ({
      cities: campaign.cities,
      level: campaign.level,
      era: campaign.era,
      totalXP: campaign.totalXP,
      balance: campaign.balance,
    }),
    [campaign],
  );
  const options = useMemo(
    () =>
      campaign.cities
        .filter(
          (p) =>
            !query ||
            `${p.city.name}${p.city.province}${p.city.landmark}`.includes(
              query.trim(),
            ),
        )
        .sort(
          (a, b) =>
            b.visits - a.visits ||
            b.level - a.level ||
            a.city.id.localeCompare(b.city.id),
        ),
    [campaign, query],
  );
  async function build() {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await mutate((d) => invest(d, selected, newId()));
      notify(`${current.city.name} · ${levelNames[current.level + 1]}已解锁`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "暂时无法建造，请重试");
    } finally {
      setBusy(false);
    }
  }
  if (hidden)
    return (
      <Screen title="山河">
        <Empty
          title="山河已隐藏"
          description="显示私人内容后继续探索。"
          action="显示山河"
          onPress={() => setHidden(false)}
          icon="lock"
        />
      </Screen>
    );
  const reachable = canReach(campaign, selected),
    cost = levelCost(current.level + 1);
  const progress =
    (campaign.totalXP - (campaign.level - 1) ** 2 * 100) /
    (campaign.nextLevelXP - (campaign.level - 1) ** 2 * 100);
  return (
    <Screen title="山河">
      <View style={{ maxWidth: 920, width: "100%", alignSelf: "center" }}>
        <View style={[s.between, { marginBottom: 16 }]}>
          <View>
            <Text style={[s.tiny, { letterSpacing: 3, color: c.green }]}>
              ASTRA · 私人征途
            </Text>
            <Text style={[s.title, { marginTop: 5 }]}>山河，由此展开</Text>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="积分规则"
            onPress={() => router.push("/game-rules")}
            style={{
              minWidth: 44,
              minHeight: 44,
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <Icon name="sliders" />
          </Pressable>
        </View>
        <View
          style={{
            backgroundColor: "#163D35",
            borderRadius: 18,
            padding: 20,
            marginBottom: 16,
          }}
        >
          <View style={[s.between, { gap: 12 }]}>
            <View style={[s.row, { gap: 12 }]}>
              <View
                style={{
                  width: 44,
                  height: 44,
                  borderRadius: 13,
                  backgroundColor: "#2C5145",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Icon
                  name={campaign.era > 1 ? "award" : "navigation"}
                  color="#DAB477"
                />
              </View>
              <View>
                <Text
                  style={{ color: "#E7DBBF", fontSize: 18, fontWeight: "600" }}
                >
                  {campaign.rank}
                </Text>
                <Text style={{ color: "#A9C2B4", fontSize: 12, marginTop: 4 }}>
                  LV.{campaign.level} · {campaign.totalXP} XP
                </Text>
              </View>
            </View>
            <View style={{ alignItems: "flex-end" }}>
              <Text
                style={{ color: "#E7C686", fontSize: 25, fontWeight: "600" }}
              >
                {campaign.balance}
              </Text>
              <Text style={{ color: "#A9C2B4", fontSize: 11 }}>可用星尘</Text>
            </View>
          </View>
          <View
            style={{
              height: 3,
              backgroundColor: "#35574A",
              marginTop: 18,
              borderRadius: 2,
            }}
          >
            <View
              style={{
                height: 3,
                width: `${Math.min(100, progress * 100)}%`,
                backgroundColor: "#C8AE75",
              }}
            />
          </View>
          <Text style={{ color: "#AAC2B5", fontSize: 11, marginTop: 8 }}>
            距下一级 {campaign.nextLevelXP - campaign.totalXP} XP · {visited}{" "}
            城足迹 · {owned} 城领地
          </Text>
        </View>
        <WorldPanel world={world} selected={selected} onSelect={setSelected} />
        <View
          style={{
            backgroundColor: c.paper,
            borderRadius: 18,
            padding: 20,
            marginTop: 14,
            borderWidth: 1,
            borderColor: c.line,
          }}
        >
          <View style={[s.between, { gap: 12 }]}>
            <View style={{ flex: 1 }}>
              <Text style={[s.tiny, { color: c.green, letterSpacing: 1 }]}>
                {biomeLabels[current.city.biome]} / {current.city.province}
              </Text>
              <Text style={[s.h2, { fontSize: 27, marginTop: 7 }]}>
                {current.city.name}
              </Text>
              <Text style={[s.muted, { marginTop: 6 }]}>
                {current.city.landmark} · {levelNames[current.level]}
              </Text>
            </View>
            <View style={{ alignItems: "flex-end" }}>
              <Text style={[s.h2, { color: c.green }]}>{current.visits}</Text>
              <Text style={s.tiny}>次记录</Text>
              <Text style={[s.tiny, { marginTop: 6 }]}>
                {current.earned} 星尘贡献
              </Text>
            </View>
          </View>
          <View style={[s.row, { gap: 6, marginVertical: 18 }]}>
            {[1, 2, 3, 4].map((level) => (
              <View key={level} style={{ flex: 1, gap: 6 }}>
                <View
                  style={{
                    height: 4,
                    borderRadius: 2,
                    backgroundColor:
                      current.level >= level ? "#8FAF92" : "#E7EAE2",
                  }}
                />
                <Text
                  style={[
                    s.tiny,
                    { color: current.level >= level ? c.green : c.muted },
                  ]}
                >
                  {levelNames[level]}
                </Text>
              </View>
            ))}
          </View>
          <ErrorNote message={error} />
          {current.level < 4 ? (
            <Button
              disabled={busy || !reachable || campaign.balance < cost}
              icon={current.level ? "layers" : "flag"}
              onPress={() => void build()}
            >{`${current.level ? "升级" : "攻占"} · ${cost} 星尘`}</Button>
          ) : (
            <Text
              style={[
                s.label,
                { color: c.green, textAlign: "center", padding: 12 },
              ]}
            >
              城市奇观已落成
            </Text>
          )}
          {current.level < 4 && (
            <Text style={[s.tiny, { marginTop: 9, textAlign: "center" }]}>
              {!reachable
                ? "在此记录一次，或从相邻领地扩张"
                : campaign.balance < cost
                  ? `还需 ${cost - campaign.balance} 星尘`
                  : "建造消耗星尘，角色经验保留"}
            </Text>
          )}
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`记录在${current.city.name}的片刻`}
            onPress={() =>
              router.push({
                pathname: "/record",
                params: { city: current.city.name },
              })
            }
            style={[
              s.row,
              { justifyContent: "center", gap: 8, minHeight: 48, marginTop: 6 },
            ]}
          >
            <Icon name="plus" size={16} />
            <Text style={s.label}>在此记录</Text>
          </Pressable>
        </View>
        {!!campaign.suspendedInvestments && (
          <Text style={[s.muted, { marginTop: 12 }]}>
            记录或规则变更后，{campaign.suspendedInvestments}{" "}
            次建造因积分或路径不足暂缓；条件恢复后会自动恢复。
          </Text>
        )}
        <View style={[s.between, { marginTop: 28, marginBottom: 15 }]}>
          <Text style={s.h2}>下一座城</Text>
          <Text style={s.tiny}>{options.length} 座城市</Text>
        </View>
        <SearchField
          label="搜索沙盘城市"
          value={query}
          onChangeText={setQuery}
          placeholder="搜索城市、省份或建筑"
        />
        <ScrollView
          style={{ maxHeight: 260, marginTop: 12 }}
          nestedScrollEnabled
        >
          {options.map((p) => (
            <Pressable
              key={p.city.id}
              accessibilityRole="button"
              accessibilityLabel={`选择${p.city.name}`}
              accessibilityState={{ selected: p.city.id === selected }}
              onPress={() => {
                setSelected(p.city.id);
                setError("");
              }}
              style={[
                s.between,
                {
                  minHeight: 66,
                  paddingHorizontal: 13,
                  borderBottomWidth: 1,
                  borderColor: c.line,
                  backgroundColor:
                    p.city.id === selected ? "#E9EEE6" : "transparent",
                },
              ]}
            >
              <View style={{ flex: 1 }}>
                <Text style={s.label}>
                  {p.city.name} <Text style={s.tiny}>· {p.city.landmark}</Text>
                </Text>
                <Text style={[s.tiny, { marginTop: 3 }]}>
                  {p.visits
                    ? `${p.visits} 次记录`
                    : canReach(campaign, p.city.id)
                      ? "可沿相邻领地扩张"
                      : "尚未探索"}
                </Text>
              </View>
              <Text style={[s.tiny, { color: p.level ? c.green : c.muted }]}>
                {levelNames[p.level]}
              </Text>
            </Pressable>
          ))}
        </ScrollView>
        {!options.length && (
          <Text style={[s.muted, { padding: 20 }]}>
            未找到城市。当前只包含内置大陆城市。
          </Text>
        )}
        {!data.entries.length && (
          <Text style={[s.muted, { marginTop: 20 }]}>
            从一条记录开始。城市首次记录可解锁探索资格，星尘由你设置的积分规则计算。
          </Text>
        )}
      </View>
    </Screen>
  );
}
