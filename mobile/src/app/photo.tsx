import React, { useState, useEffect } from "react";
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  useWindowDimensions,
} from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  runOnJS,
} from "react-native-reanimated";
import { useApp } from "../data/store";
import { Icon, c, s } from "../design/ui";
export default function PhotoViewer() {
  const { id, index: initial } = useLocalSearchParams<{
    id: string;
    index?: string;
  }>();
  const { data, hidden } = useApp();
  const person = data.people.find((p) => p.id === id),
    photos = person?.album || [];
  const [index, setIndex] = useState(
    Math.min(Math.max(0, Number(initial) || 0), Math.max(0, photos.length - 1)),
  );
  const insets = useSafeAreaInsets(),
    { width, height } = useWindowDimensions();
  const scale = useSharedValue(1),
    savedScale = useSharedValue(1),
    x = useSharedValue(0),
    y = useSharedValue(0),
    originX = useSharedValue(0),
    originY = useSharedValue(0);
  const next = (direction: number) =>
    setIndex((i) => Math.max(0, Math.min(photos.length - 1, i + direction)));
  useEffect(() => {
    scale.value = 1;
    savedScale.value = 1;
    x.value = 0;
    y.value = 0;
  }, [index]);
  const pinch = Gesture.Pinch()
    .onUpdate((e) => {
      scale.value = Math.min(4, Math.max(1, savedScale.value * e.scale));
    })
    .onEnd(() => {
      savedScale.value = scale.value;
      if (scale.value <= 1) {
        x.value = withTiming(0);
        y.value = withTiming(0);
      }
    });
  const pan = Gesture.Pan()
    .onStart(() => {
      originX.value = x.value;
      originY.value = y.value;
    })
    .onUpdate((e) => {
      if (scale.value > 1) {
        x.value = originX.value + e.translationX;
        y.value = originY.value + e.translationY;
      }
    })
    .onEnd((e) => {
      if (scale.value === 1 && Math.abs(e.translationX) > 70)
        runOnJS(next)(e.translationX < 0 ? 1 : -1);
    });
  const imageStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: x.value },
      { translateY: y.value },
      { scale: scale.value },
    ],
  }));
  const source =
    photos[index] === "demo:portrait"
      ? require("../../assets/editorial-portrait.png")
      : photos[index]
        ? { uri: photos[index] }
        : undefined;
  return (
    <View style={{ flex: 1, backgroundColor: "#101319" }}>
      <View
        style={{
          paddingTop: insets.top + 10,
          paddingHorizontal: 17,
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "space-between",
          zIndex: 2,
        }}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="关闭相册"
          onPress={() => router.back()}
          style={{ padding: 13 }}
        >
          <Icon name="x" color="#fff" />
        </Pressable>
        <Text style={[s.label, { color: "#fff" }]}>
          {hidden ? "已隐藏" : person?.name || "私藏"}
        </Text>
        <Text
          style={[
            s.tiny,
            { color: "#AEB7C7", minWidth: 46, textAlign: "right" },
          ]}
        >
          {photos.length ? index + 1 : 0} / {photos.length}
        </Text>
      </View>
      <GestureDetector gesture={Gesture.Simultaneous(pinch, pan)}>
        <Animated.View
          style={[{ flex: 1, justifyContent: "center" }, imageStyle]}
        >
          {source && !hidden && (
            <Image
              source={source}
              style={{
                width,
                height: height - insets.top - insets.bottom - 160,
              }}
              contentFit="contain"
              accessibilityLabel="私藏照片"
            />
          )}
        </Animated.View>
      </GestureDetector>
      <View
        style={{
          flexDirection: "row",
          justifyContent: "center",
          gap: 25,
          paddingBottom: insets.bottom + 20,
          alignItems: "center",
        }}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="上一张"
          disabled={index === 0}
          onPress={() => next(-1)}
          style={{ padding: 14, opacity: index === 0 ? 0.3 : 1 }}
        >
          <Icon name="arrow-left" color="#fff" />
        </Pressable>
        <Text style={[s.tiny, { color: "#AEB7C7" }]}>双指缩放 · 左右翻阅</Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="下一张"
          disabled={index >= photos.length - 1}
          onPress={() => next(1)}
          style={{ padding: 14, opacity: index >= photos.length - 1 ? 0.3 : 1 }}
        >
          <Icon name="arrow-right" color="#fff" />
        </Pressable>
      </View>
    </View>
  );
}
