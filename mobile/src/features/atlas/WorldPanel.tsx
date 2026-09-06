import React, { useEffect, useState } from "react";
import {
  AppState,
  Linking,
  Modal,
  Pressable,
  ScrollView,
  Text,
  View,
} from "react-native";
import { useIsFocused } from "@react-navigation/native";
import { Icon } from "../../design/ui";
import AtlasCanvas from "../../platform/atlas/AtlasCanvas";
import type { MapCommand } from "../../platform/atlas/types";
import { regions, regionProgress } from "../../game/map2d";
import type { WorldView } from "../../game/types";

class SceneBoundary extends React.Component<
  { children: React.ReactNode },
  { failed: boolean }
> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  render() {
    return this.state.failed ? (
      <View
        style={{
          flex: 1,
          alignItems: "center",
          justifyContent: "center",
          padding: 24,
        }}
      >
        <Text style={{ color: "#DAD7C9", textAlign: "center" }}>
          地图暂不可用。仍可通过下方城市列表探索、攻城和升级。
        </Text>
      </View>
    ) : (
      this.props.children
    );
  }
}
export default function WorldPanel({
  world,
  selected,
  onSelect,
}: {
  world: WorldView;
  selected: string;
  onSelect: (id: string) => void;
}) {
  const [command, setCommand] = useState<MapCommand>({
    kind: "reset",
    revision: 0,
  });
  const [active, setActive] = useState(
    AppState.currentState !== "background" &&
      AppState.currentState !== "inactive",
  );
  const [flat, setFlat] = useState(false),
    [focusCity, setFocusCity] = useState(false),
    [source, setSource] = useState(false);
  const focused = useIsFocused();
  useEffect(() => {
    const sub = AppState.addEventListener("change", (s) =>
      setActive(s === "active"),
    );
    return () => sub.remove();
  }, []);
  const send = (kind: MapCommand["kind"]) => {
    setFocusCity(false);
    setFlat(false);
    setCommand((c) => ({ kind, revision: c.revision + 1 }));
  };
  const city = world.cities.find((p) => p.city.id === selected);
  const region = regions.find((r) => r.id === selected.slice(0, 2));
  const progress = region ? regionProgress(region, world.cities) : undefined;
  const control = (
    label: string,
    icon: React.ComponentProps<typeof Icon>["name"],
    action: () => void,
  ) => (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={action}
      style={{
        width: 44,
        height: 44,
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "#244A40",
        borderRadius: 12,
      }}
    >
      <Icon name={icon} color="#D2C39D" size={18} />
    </Pressable>
  );
  return (
    <View
      style={{
        height: 450,
        borderRadius: 20,
        overflow: "hidden",
        backgroundColor: "#102D2B",
      }}
    >
      <View style={{ flex: 1, overflow: "hidden" }}>
        {!flat && active && focused ? (
          <SceneBoundary>
            <AtlasCanvas
              world={world}
              selected={selected}
              onSelect={onSelect}
              command={command}
              focusCity={focusCity}
            />
          </SceneBoundary>
        ) : (
          <View
            style={{
              flex: 1,
              alignItems: "center",
              justifyContent: "center",
              gap: 14,
            }}
          >
            <Icon name="map" color="#D2C39D" size={42} />
            <Text style={{ color: "#C9D9CD" }}>
              城市列表模式 · 下方操作完整可用
            </Text>
          </View>
        )}
        <View
          pointerEvents="box-none"
          style={{ position: "absolute", top: 10, left: 18, right: 18 }}
        >
          <View
            pointerEvents="none"
            style={{
              flexDirection: "row",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <Text style={{ color: "#DAB477", fontSize: 11, letterSpacing: 3 }}>
              ASTRA / 山河图卷
            </Text>
            <Text style={{ color: "#ABC2B9", fontSize: 10 }}>2D · 离线</Text>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="地图数据来源"
            onPress={() => setSource(true)}
            style={{ minHeight: 44, justifyContent: "center" }}
          >
            <Text style={{ color: "#ABC2B9", fontSize: 10 }}>
              省级边界 © geoBoundaries · 2019 · 数据说明 ↗
            </Text>
          </Pressable>
        </View>
        <View
          pointerEvents="none"
          style={{
            position: "absolute",
            left: 18,
            right: 18,
            bottom: 12,
            gap: 4,
          }}
        >
          <Text style={{ fontSize: 11, color: "#DBD3AD" }}>
            {focusCity
              ? `${city?.city.landmark} · ${city?.level ? "当前已解锁外观" : "奇观预览 · 尚未解锁"}`
              : `${region?.name ?? "山河"} · 足迹 ${progress?.visited ?? 0}/${progress?.total ?? 0} 城 · 领地 ${progress?.owned ?? 0} 城`}
          </Text>
          <Text style={{ fontSize: 10, color: "#A8C3B4" }}>
            {focusCity
              ? "专属建筑随城市等级成长"
              : "拖动探索 · 双指缩放 · 点击城市或省域"}
          </Text>
        </View>
      </View>
      <View
        style={{
          height: 62,
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "space-between",
          paddingHorizontal: 14,
          borderTopWidth: 1,
          borderTopColor: "#31534A",
        }}
      >
        {control("放大沙盘", "plus", () => send("in"))}
        {control("缩小沙盘", "minus", () => send("out"))}
        {control("重置沙盘", "maximize", () => send("reset"))}
        {control("定位所选城市", "crosshair", () => send("locate"))}
        {control(
          focusCity ? "返回全景沙盘" : "预览城市建筑",
          focusCity ? "globe" : "box",
          () => {
            setFlat(false);
            setFocusCity((v) => !v);
          },
        )}
        {control(
          flat ? "打开2D沙盘" : "切换列表模式",
          flat ? "map" : "list",
          () => setFlat((v) => !v),
        )}
      </View>
      <Modal
        visible={source && active && focused}
        animationType="none"
        transparent
        onRequestClose={() => setSource(false)}
      >
        <View
          style={{
            flex: 1,
            justifyContent: "center",
            padding: 24,
            backgroundColor: "#0009",
          }}
        >
          <View
            accessibilityViewIsModal
            style={{
              maxHeight: "80%",
              backgroundColor: "#F6F3E9",
              borderRadius: 20,
              padding: 22,
            }}
          >
            <Text
              style={{
                fontSize: 22,
                fontWeight: "700",
                color: "#244637",
                marginBottom: 12,
              }}
            >
              地图数据
            </Text>
            <ScrollView>
              <Text style={{ fontSize: 14, lineHeight: 23, color: "#45594C" }}>
                省界来自 geoBoundaries gbOpen CHN ADM1（Wikimedia
                Commons），表示年份 2019，发布构建 2023-12-12。源几何许可为
                Public Domain；geoBoundaries 数据库按 CC BY 4.0 署名。{"\n\n"}
                采用 WGS-84 坐标，离线保存全部 34 个省级区域；大陆 31
                个省级区域参与游戏。城市中心来自应用内置目录。省域颜色汇总城市发展，实际占领按城市单独记录，不代表占领整个省域。
                {"\n\n"}
                此版本是经过坐标取整的概览地图，不是实时行政数据或测绘底图。没有地级市边界、道路与高程。山脉和建筑为原创游戏图形。
              </Text>
              <Pressable
                accessibilityRole="link"
                onPress={() =>
                  void Linking.openURL(
                    "https://www.geoboundaries.org/api/current/gbOpen/CHN/ADM1/",
                  )
                }
                style={{
                  minHeight: 44,
                  justifyContent: "center",
                  marginTop: 12,
                }}
              >
                <Text style={{ color: "#337C66" }}>
                  查看 geoBoundaries 数据来源 ↗
                </Text>
              </Pressable>
            </ScrollView>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="关闭地图数据说明"
              onPress={() => setSource(false)}
              style={{
                minHeight: 44,
                justifyContent: "center",
                alignItems: "center",
                marginTop: 8,
              }}
            >
              <Text style={{ color: "#244637", fontWeight: "700" }}>
                知道了
              </Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </View>
  );
}
