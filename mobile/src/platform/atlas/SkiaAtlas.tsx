import React, { memo, useEffect, useMemo, useState } from "react";
import { Text, View } from "react-native";
import {
  Canvas,
  Circle,
  Fill,
  Group,
  LinearGradient,
  Path,
  vec,
} from "@shopify/react-native-skia";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useDerivedValue,
  useSharedValue,
  type SharedValue,
} from "react-native-reanimated";
import {
  cityCamera,
  clampCamera,
  fitCamera,
  fromScreen,
  mapProject,
  selectAt,
  zoomAt,
  type Camera,
  type Point,
} from "../../game/map2d";
import { landmark2d, type Ink } from "../../game/landmarks2d";
import { majorCities, mapScene, player2d, terrain } from "../../game/scene2d";
import type { AtlasProps } from "./types";

const InkPaths = memo(function InkPaths({ paths }: { paths: Ink[] }) {
  return (
    <>
      {paths.map((p, i) => (
        <Path
          key={i}
          path={p.path}
          color={p.color}
          style={p.strokeWidth ? "stroke" : "fill"}
          strokeWidth={p.strokeWidth}
          opacity={p.opacity ?? 1}
        />
      ))}
    </>
  );
});
function CityLabel({
  x,
  y,
  name,
  chosen,
  camera,
}: Point & { name: string; chosen: boolean; camera: SharedValue<Camera> }) {
  const style = useAnimatedStyle(() => ({
    transform: [
      { translateX: camera.value.x + x * camera.value.scale - 35 },
      { translateY: camera.value.y + y * camera.value.scale + 8 },
    ],
  }));
  return (
    <Animated.View
      pointerEvents="none"
      style={[{ position: "absolute", width: 70 }, style]}
    >
      <Text
        numberOfLines={1}
        style={{
          fontSize: chosen ? 12 : 10,
          fontWeight: chosen ? "700" : "500",
          textAlign: "center",
          color: chosen ? "#F7DDA2" : "#D1DEC8",
          textShadowColor: "#10362F",
          textShadowRadius: 3,
          textShadowOffset: { width: 0, height: 1 },
        }}
      >
        {name}
      </Text>
    </Animated.View>
  );
}
export default function SkiaAtlas({
  world,
  selected,
  onSelect,
  command,
  focusCity,
}: AtlasProps) {
  const [view, setView] = useState({ width: 0, height: 0 });
  const camera = useSharedValue<Camera>({ x: 0, y: 0, scale: 1 });
  const pinching = useSharedValue(false);
  const pinchStart = useSharedValue<Camera>({ x: 0, y: 0, scale: 1 });
  const pinchAnchor = useSharedValue<Point>({ x: 0, y: 0 });
  const scene = useMemo(() => mapScene(world, selected), [world, selected]);
  const city = world.cities.find((p) => p.city.id === selected);
  const preview = useMemo(
    () => (city ? landmark2d(city.city, city.level || 4) : []),
    [city],
  );
  const player = useMemo(() => player2d(world.era), [world.era]);
  const transform = useDerivedValue(() => [
    { translateX: camera.value.x },
    { translateY: camera.value.y },
    { scale: camera.value.scale },
  ]);
  const detailOpacity = useDerivedValue(() =>
    Math.min(
      1,
      Math.max(0, (camera.value.scale / fitCamera(view).scale - 1.1) / 1.2),
    ),
  );
  useEffect(() => {
    if (view.width) camera.value = fitCamera(view);
  }, [view, camera]);
  useEffect(() => {
    if (!view.width) return;
    if (command.kind === "reset") camera.value = fitCamera(view);
    else if (command.kind === "locate") {
      const target = world.cities.find((p) => p.city.id === selected);
      if (target)
        camera.value = cityCamera(
          mapProject(target.city.lon, target.city.lat),
          view,
        );
    } else
      camera.value = zoomAt(
        camera.value,
        { x: view.width * 0.45, y: view.height * 0.52 },
        command.kind === "in" ? 1.4 : 1 / 1.4,
        view,
      );
    // Consume each command once; selection does not reset a manually moved camera.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [command, view, camera]);
  const choose = (x: number, y: number, current: Camera) => {
    const id = selectAt({ x, y }, current, world.cities);
    if (id) onSelect(id);
  };
  const pan = Gesture.Pan()
    .enabled(!focusCity)
    .maxPointers(1)
    .minDistance(7)
    .onChange((e) => {
      if (e.numberOfPointers === 1 && !pinching.value)
        camera.value = clampCamera(
          {
            ...camera.value,
            x: camera.value.x + e.changeX,
            y: camera.value.y + e.changeY,
          },
          view,
        );
    });
  const pinch = Gesture.Pinch()
    .enabled(!focusCity)
    .onStart((e) => {
      pinching.value = true;
      pinchStart.value = camera.value;
      pinchAnchor.value = fromScreen(
        { x: e.focalX, y: e.focalY },
        camera.value,
      );
    })
    .onUpdate((e) => {
      const base = fitCamera(view),
        scale = Math.min(
          base.scale * 7,
          Math.max(base.scale, pinchStart.value.scale * e.scale),
        );
      camera.value = clampCamera(
        {
          scale,
          x: e.focalX - pinchAnchor.value.x * scale,
          y: e.focalY - pinchAnchor.value.y * scale,
        },
        view,
      );
    })
    .onFinalize(() => {
      pinching.value = false;
    });
  const tap = Gesture.Tap()
    .enabled(!focusCity)
    .maxDistance(7)
    .onEnd((e, success) => {
      if (success) runOnJS(choose)(e.x, e.y, camera.value);
    });
  const gesture = Gesture.Race(Gesture.Simultaneous(pan, pinch), tap);
  const selectedMarker = scene.markers.find((m) => m.chosen);
  return (
    <GestureDetector gesture={gesture}>
      <View
        collapsable={false}
        accessibilityLabel="二维山河地图"
        accessibilityHint="拖动探索，双指缩放。也可用地图按钮与下方城市列表操作。"
        style={{ flex: 1 }}
        onLayout={(e) => {
          const { width, height } = e.nativeEvent.layout;
          setView((v) =>
            v.width === width && v.height === height ? v : { width, height },
          );
        }}
      >
        {view.width > 0 && (
          <>
            <Canvas style={{ flex: 1 }}>
              <Fill>
                <LinearGradient
                  start={vec(0, 0)}
                  end={vec(view.width, view.height)}
                  colors={["#0D302E", "#194D48", "#102F31"]}
                />
              </Fill>
              {focusCity ? (
                <Group
                  transform={[
                    { translateX: view.width * 0.44 },
                    { translateY: view.height * 0.65 },
                    { scale: Math.min(view.width / 160, 2.7) },
                  ]}
                >
                  <Circle
                    cx={0}
                    cy={-15}
                    r={65}
                    color="#B6C891"
                    opacity={0.06}
                  />
                  <Circle
                    cx={0}
                    cy={-15}
                    r={54}
                    color="#CDB67A"
                    style="stroke"
                    strokeWidth={0.5}
                    opacity={0.4}
                  />
                  <InkPaths paths={preview} />
                  <Group
                    transform={[
                      { translateX: -43 },
                      { translateY: 26 },
                      { scale: 0.8 },
                    ]}
                  >
                    <InkPaths paths={player} />
                  </Group>
                </Group>
              ) : (
                <Group transform={transform}>
                  {scene.territory.map((r, i) => (
                    <Group key={i}>
                      <Path path={r.path} color={r.color} fillType="evenOdd" />
                      <Path
                        path={r.path}
                        color={r.border}
                        style="stroke"
                        strokeWidth={1.5}
                        opacity={0.65}
                      />
                    </Group>
                  ))}
                  <InkPaths paths={terrain} />
                  <Group opacity={detailOpacity}>
                    {scene.markers
                      .filter((m) => !m.important)
                      .map((m) => (
                        <Circle
                          key={m.id}
                          cx={m.x}
                          cy={m.y}
                          r={2.2}
                          color={m.color}
                          opacity={0.8}
                        />
                      ))}
                  </Group>
                  {scene.markers
                    .filter((m) => m.important)
                    .map((m) => (
                      <Group
                        key={m.id}
                        transform={[{ translateX: m.x }, { translateY: m.y }]}
                      >
                        {m.chosen && (
                          <>
                            <Circle r={23} color="#E5BE78" opacity={0.13} />
                            <Circle
                              r={19}
                              color="#F3CC82"
                              style="stroke"
                              strokeWidth={2}
                            />
                          </>
                        )}
                        <Circle r={m.level ? 5 : 3.5} color={m.color} />
                        <Group
                          transform={[{ scale: m.artScale }]}
                          opacity={m.opacity}
                        >
                          <InkPaths paths={m.art} />
                        </Group>
                      </Group>
                    ))}
                  {selectedMarker && (
                    <Group
                      transform={[
                        { translateX: selectedMarker.x - 22 },
                        { translateY: selectedMarker.y + 10 },
                        { scale: 0.6 },
                      ]}
                    >
                      <InkPaths paths={player} />
                    </Group>
                  )}
                </Group>
              )}
            </Canvas>
            {!focusCity &&
              scene.markers
                .filter((m) => m.chosen || majorCities.has(m.id))
                .map((m) => <CityLabel key={m.id} {...m} camera={camera} />)}
          </>
        )}
      </View>
    </GestureDetector>
  );
}
