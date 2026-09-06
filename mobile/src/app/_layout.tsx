import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  AppState,
  Platform,
  ActivityIndicator,
} from "react-native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { useFonts } from "expo-font";
import { Feather } from "@expo/vector-icons";
import * as LocalAuthentication from "expo-local-authentication";
import * as ScreenCapture from "expo-screen-capture";
import { useApp } from "../data/store";
import { Button, c, s, Icon } from "../design/ui";

export default function Layout() {
  const [fontsLoaded, fontError] = useFonts(Feather.font);
  const { ready, error, hydrate, data, toast, unlocked } = useApp();
  const [unlockError, setUnlockError] = useState("");
  const [background, setBackground] = useState(false),
    [unlocking, setUnlocking] = useState(false);
  useEffect(() => {
    void hydrate();
    if (Platform.OS === "ios")
      void ScreenCapture.enableAppSwitcherProtectionAsync(1).catch(() => {});
  }, []);
  useEffect(() => {
    const sub = AppState.addEventListener("change", (state) => {
      setBackground(state !== "active");
      if (state === "background") useApp.setState({ unlocked: false });
    });
    return () => sub.remove();
  }, []);
  const unlock = async () => {
    setUnlocking(true);
    setUnlockError("");
    try {
      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: "解锁 Astra",
        cancelLabel: "取消",
      });
      if (result.success) useApp.setState({ unlocked: true });
    } catch {
      setUnlockError("设备认证暂不可用，请重试。");
    } finally {
      setUnlocking(false);
    }
  };
  if (!ready || (!fontsLoaded && !fontError))
    return (
      <View
        style={{
          flex: 1,
          backgroundColor: c.bg,
          alignItems: "center",
          justifyContent: "center",
          gap: 20,
        }}
      >
        {error ? (
          <>
            <Text style={s.body}>{error}</Text>
            <Button onPress={() => void hydrate()}>重试</Button>
          </>
        ) : (
          <ActivityIndicator color={c.blue} />
        )}
      </View>
    );
  const needsLock = Platform.OS !== "web" && data.settings.appLock && !unlocked;
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <StatusBar style="dark" />
      <View
        style={{ flex: 1 }}
        accessibilityElementsHidden={background || needsLock}
        importantForAccessibility={
          background || needsLock ? "no-hide-descendants" : "auto"
        }
      >
        <Stack
          screenOptions={{
            headerShown: false,
            contentStyle: { backgroundColor: c.bg },
            animation: "slide_from_right",
          }}
        >
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="game-rules" options={{ gestureEnabled: false }} />
          <Stack.Screen name="record" options={{ presentation: "modal", gestureEnabled: false }} />
          <Stack.Screen
            name="person/edit"
            options={{ presentation: "modal", gestureEnabled: false }}
          />
          <Stack.Screen
            name="photo"
            options={{ presentation: "fullScreenModal" }}
          />
        </Stack>
      </View>
      {!!toast && (
        <View
          pointerEvents="none"
          style={{
            position: "absolute",
            bottom: 105,
            alignSelf: "center",
            backgroundColor: c.ink,
            paddingHorizontal: 20,
            paddingVertical: 13,
            borderRadius: 30,
            maxWidth: "90%",
            flexDirection: "row",
            gap: 10,
            alignItems: "center",
          }}
        >
          <Icon name="check-circle" size={17} color="#A8F2CE" />
          <Text
            accessibilityLiveRegion="polite"
            style={[s.label, { color: "#fff" }]}
          >
            {toast}
          </Text>
        </View>
      )}
      {(background || needsLock) && (
        <View
          style={[
            StyleSheet.absoluteFill,
            {
              backgroundColor: c.bg,
              alignItems: "center",
              justifyContent: "center",
              gap: 24,
            },
          ]}
        >
          <View style={{ width: 78, height: 78, borderRadius: 23, backgroundColor: c.paper, alignItems: "center", justifyContent: "center", marginBottom: 3 }}><Icon name="aperture" size={34} color={c.ink} /></View>
          <Text style={[s.title, { fontSize: 29 }]}>私人档案已锁定</Text>
          <Text style={[s.muted, { marginTop: -13 }]}>{unlockError || "验证身份，继续你的故事。"}</Text>
          {needsLock && !background && (
            <Button onPress={() => void unlock()} disabled={unlocking}>
              解锁 Astra
            </Button>
          )}
        </View>
      )}
    </GestureHandlerRootView>
  );
}
