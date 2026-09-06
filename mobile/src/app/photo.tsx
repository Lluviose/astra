import React, { useState } from "react";
import { View, Text, Pressable, ScrollView, StyleSheet } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { Image } from "expo-image";
import { StatusBar } from "expo-status-bar";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import Animated, { useSharedValue, useAnimatedStyle, withTiming, runOnJS } from "react-native-reanimated";
import { useApp } from "../data/store";
import { Icon, s } from "../design/ui";

function sourceFor(uri: string) {
  return uri === "demo:portrait"
    ? require("../../assets/editorial-portrait.png")
    : { uri };
}

function PhotoStage({ uri, onPage }: { uri: string; onPage: (direction: number) => void }) {
  const [size, setSize] = useState({ width: 1, height: 1 });
  const scale = useSharedValue(1), savedScale = useSharedValue(1);
  const x = useSharedValue(0), y = useSharedValue(0);
  const originX = useSharedValue(0), originY = useSharedValue(0);
  const pinch = Gesture.Pinch()
    .onUpdate(event => {
      scale.value = Math.min(4, Math.max(1, savedScale.value * event.scale));
    })
    .onEnd(() => {
      savedScale.value = scale.value;
      const limitX = size.width * (scale.value - 1) / 2;
      const limitY = size.height * (scale.value - 1) / 2;
      x.value = withTiming(Math.max(-limitX, Math.min(limitX, x.value)));
      y.value = withTiming(Math.max(-limitY, Math.min(limitY, y.value)));
    });
  const pan = Gesture.Pan()
    .onStart(() => { originX.value = x.value; originY.value = y.value; })
    .onUpdate(event => {
      if (scale.value > 1) {
        const limitX = size.width * (scale.value - 1) / 2;
        const limitY = size.height * (scale.value - 1) / 2;
        x.value = Math.max(-limitX, Math.min(limitX, originX.value + event.translationX));
        y.value = Math.max(-limitY, Math.min(limitY, originY.value + event.translationY));
      }
    })
    .onEnd(event => {
      if (scale.value === 1 && Math.abs(event.translationX) > 70 && Math.abs(event.translationX) > Math.abs(event.translationY)) {
        runOnJS(onPage)(event.translationX < 0 ? 1 : -1);
      }
    });
  const doubleTap = Gesture.Tap().numberOfTaps(2).onEnd((_event, success) => {
    if (!success) return;
    const target = scale.value > 1 ? 1 : 2;
    scale.value = withTiming(target);
    savedScale.value = target;
    x.value = withTiming(0);
    y.value = withTiming(0);
  });
  const imageStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: x.value }, { translateY: y.value }, { scale: scale.value }],
  }));
  return (
    <View onLayout={event => setSize(event.nativeEvent.layout)} style={{ flex: 1, overflow: "hidden", marginVertical: 12 }}>
      <GestureDetector gesture={Gesture.Simultaneous(pinch, pan, doubleTap)}>
        <Animated.View style={[{ flex: 1 }, imageStyle]}>
          <Image source={sourceFor(uri)} style={StyleSheet.absoluteFill} contentFit="contain" accessibilityLabel="私藏照片" />
        </Animated.View>
      </GestureDetector>
    </View>
  );
}

export default function PhotoViewer() {
  const { id, index: initial } = useLocalSearchParams<{ id: string; index?: string }>();
  const { data, hidden } = useApp();
  const person = data.people.find(p => p.id === id);
  const photos = person?.album || [];
  const [index, setIndex] = useState(Math.max(0, Math.floor(Number(initial) || 0)));
  const current = Math.min(index, Math.max(0, photos.length - 1));
  const insets = useSafeAreaInsets();
  const multiple = photos.length > 1 && !hidden;
  const next = (direction: number) => setIndex(Math.max(0, Math.min(photos.length - 1, current + direction)));
  return (
    <View style={{ flex: 1, backgroundColor: "#111412" }}>
      <StatusBar style="light" />
      <View style={[s.between, { paddingTop: insets.top + 8, paddingHorizontal: 16, gap: 16 }]}>
        <Pressable accessibilityRole="button" accessibilityLabel="关闭相册" onPress={() => router.canGoBack() ? router.back() : router.replace("/roster")} style={styles.close}>
          <Icon name="x" size={20} color="#fff" />
        </Pressable>
        <Text numberOfLines={1} style={[s.label, { color: "#F5F7F3", flex: 1, textAlign: "center" }]}>{hidden ? "已隐藏" : person?.name || "私藏"}</Text>
        <Text style={[s.tiny, { color: "#BBC1BC", minWidth: 44, textAlign: "right", fontVariant: ["tabular-nums"] }]}>{multiple ? `${current + 1} / ${photos.length}` : ""}</Text>
      </View>
      {!hidden && photos[current] ? (
        <PhotoStage key={`${current}-${photos[current]}`} uri={photos[current]} onPage={next} />
      ) : (
        <View style={{ flex: 1, alignItems: "center", justifyContent: "center", gap: 14 }}>
          <Icon name={hidden ? "eye-off" : "image"} color="#BBC1BC" size={26} />
          <Text style={[s.muted, { color: "#BBC1BC" }]}>{hidden ? "私人照片已隐藏" : "这里还没有照片"}</Text>
        </View>
      )}
      <View style={{ paddingBottom: Math.max(insets.bottom, 14), paddingHorizontal: 16 }}>
        {multiple && <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 5, flexGrow: 1, justifyContent: "center", paddingBottom: 10 }}>
          {photos.map((uri, i) => <Pressable key={`${uri}-${i}`} accessibilityRole="button" accessibilityLabel={`查看第${i + 1}张照片`} accessibilityState={{ selected: i === current }} onPress={() => setIndex(i)} style={[styles.thumbnail, { borderColor: i === current ? "#EDF1E9" : "transparent", opacity: i === current ? 1 : 0.55 }]}>
            <Image source={sourceFor(uri)} style={{ width: 36, height: 44, borderRadius: 3 }} contentFit="cover" />
          </Pressable>)}
        </ScrollView>}
        {!hidden && !!photos.length && <View style={[s.row, { justifyContent: "center", gap: 12, minHeight: 44 }]}>
          {multiple && <Pressable accessibilityRole="button" accessibilityLabel="上一张" accessibilityState={{ disabled: current === 0 }} disabled={current === 0} onPress={() => next(-1)} style={[styles.arrow, { opacity: current === 0 ? 0.3 : 1 }]}><Icon name="arrow-left" size={19} color="#fff" /></Pressable>}
          <Text style={[s.tiny, { color: "#BBC1BC", textAlign: "center", flexShrink: 1 }]}>双击或双指缩放{multiple ? " · 滑动翻阅" : ""}</Text>
          {multiple && <Pressable accessibilityRole="button" accessibilityLabel="下一张" accessibilityState={{ disabled: current === photos.length - 1 }} disabled={current === photos.length - 1} onPress={() => next(1)} style={[styles.arrow, { opacity: current === photos.length - 1 ? 0.3 : 1 }]}><Icon name="arrow-right" size={19} color="#fff" /></Pressable>}
        </View>}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  close: { width: 44, height: 44, alignItems: "center", justifyContent: "center", backgroundColor: "#282D29", borderRadius: 22 },
  arrow: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  thumbnail: { minWidth: 48, minHeight: 54, padding: 3, borderWidth: 1, borderRadius: 6, alignItems: "center", justifyContent: "center" },
});
