import React, { useEffect, useState } from "react";
import { AppState, Pressable, Text, View } from "react-native";
import { useIsFocused } from "@react-navigation/native";
import { Icon } from "../../design/ui";
import AtlasCanvas from "../../platform/atlas/AtlasCanvas";
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
          3D 暂不可用。仍可通过下方城市列表探索、攻城和升级。
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
  const [rotation, setRotation] = useState(-0.08),
    [zoom, setZoom] = useState(0.88),
    [active, setActive] = useState(
      AppState.currentState !== "background" &&
        AppState.currentState !== "inactive",
    ),
    [flat, setFlat] = useState(false);
  const [focusCity, setFocusCity] = useState(false);
  const focused = useIsFocused();
  useEffect(() => {
    const sub = AppState.addEventListener("change", (s) =>
      setActive(s === "active"),
    );
    return () => sub.remove();
  }, []);
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
        backgroundColor: "#1E403A",
        borderRadius: 12,
      }}
    >
      <Icon name={icon} color="#D2C39D" size={18} />
    </Pressable>
  );
  return (
    <View
      style={{
        height: 360,
        borderRadius: 20,
        overflow: "hidden",
        backgroundColor: "#102D2B",
      }}
    >
      {!flat && active && focused ? (
        <SceneBoundary>
          <AtlasCanvas
            world={world}
            selected={selected}
            onSelect={onSelect}
            rotation={rotation}
            zoom={zoom}
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
        pointerEvents="none"
        style={{ position: "absolute", top: 18, left: 18 }}
      >
        <Text style={{ color: "#DAB477", fontSize: 11, letterSpacing: 3 }}>
          ASTRA / 山河沙盘
        </Text>
        <Text style={{ color: "#ABC2B9", fontSize: 11, marginTop: 6 }}>
          大陆城市 · 地形与边界为游戏示意
        </Text>
      </View>
      <View style={{ position: "absolute", right: 12, bottom: 14, gap: 6 }}>
        {control("放大沙盘", "plus", () =>
          setZoom((z) => Math.min(1.6, z + 0.15)),
        )}
        {control("缩小沙盘", "minus", () =>
          setZoom((z) => Math.max(0.65, z - 0.15)),
        )}
        {control("旋转沙盘", "rotate-cw", () =>
          setRotation((r) => r + Math.PI / 6),
        )}
        {control(
          focusCity ? "返回全景沙盘" : "预览城市建筑",
          focusCity ? "globe" : "box",
          () => setFocusCity((v) => !v),
        )}
        {control(
          flat ? "打开3D沙盘" : "切换列表模式",
          flat ? "box" : "list",
          () => setFlat((v) => !v),
        )}
      </View>
      <Text
        pointerEvents="none"
        style={{
          position: "absolute",
          left: 18,
          bottom: 17,
          fontSize: 11,
          color: "#AAC5B9",
        }}
      >
        {focusCity
          ? `${world.cities.find((p) => p.city.id === selected)?.city.landmark} · ${world.cities.find((p) => p.city.id === selected)?.level ? "当前已解锁外观" : "奇观预览 · 尚未解锁"}`
          : "点击城标选城 · 金环为当前目标"}
      </Text>
    </View>
  );
}
