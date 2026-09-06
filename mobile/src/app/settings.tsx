import React, { useState } from "react";
import { View, Text, Switch, Platform, Pressable } from "react-native";
import { router } from "expo-router";
import * as LocalAuthentication from "expo-local-authentication";
import { useApp } from "../data/store";
import { emptyData, type Settings } from "../domain/model";
import { demoData } from "../domain/demo";
import { Screen, Field, Button, ErrorNote, Icon, PageTitle, FormSection, c, s, type IconName } from "../design/ui";
import Confirm from "../design/Confirm";

export default function SettingsScreen() {
  const { data, mutate, notify, setHidden } = useApp();
  const [title, setTitle] = useState(data.settings.title),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [reset, setReset] = useState(false);
  async function update(patch: Partial<Settings>) {
    setBusy(true);
    setError("");
    try {
      await mutate((d) => ({ ...d, settings: { ...d.settings, ...patch } }));
      return true;
    } catch {
      setError("设置未能保存，请重试");
      return false;
    } finally {
      setBusy(false);
    }
  }
  async function appLock(value: boolean) {
    setBusy(true);
    setError("");
    try {
      if (value) {
        if (Platform.OS === "web") { setError("请在 iOS 应用中启用设备解锁。"); return; }
        if (!(await LocalAuthentication.isEnrolledAsync())) { setError("请先在设备设置中配置面容 ID 或触控 ID。"); return; }
        const result = await LocalAuthentication.authenticateAsync({ promptMessage: "启用 Astra 解锁保护" });
        if (!result.success) return;
        useApp.setState({ unlocked: true });
      }
      await update({ appLock: value });
    } catch { setError("设备认证暂不可用，请稍后重试。"); }
    finally { setBusy(false); }
  }
  async function loadDemo() {
    setBusy(true);
    try {
      await mutate(() => demoData());
      setHidden(false);
      notify("已载入虚构示例");
      router.replace("/");
    } catch {
      setError("示例未能载入");
    } finally {
      setBusy(false);
    }
  }
  async function clear() {
    setBusy(true);
    try {
      await mutate(() => emptyData());
      setHidden(false);
      setReset(false);
      notify("已开始空白档案");
      router.replace("/");
    } catch {
      setError("未能清空，请重试");
      setReset(false);
    } finally {
      setBusy(false);
    }
  }
  return <Screen back title="偏好设置"><View style={{ maxWidth: 640, width: "100%", alignSelf: "center" }}>
    <PageTitle title="偏好" subtitle="隐私、触感，以及属于你的表达" />
    <ErrorNote message={error} />
    <View style={[s.row, { gap: 15, paddingBottom: 25, marginBottom: 22, borderBottomWidth: 1, borderColor: c.line }]}><View style={{ width: 45, height: 45, borderRadius: 12, backgroundColor: c.ink, alignItems: "center", justifyContent: "center" }}><Icon name="lock" color="#fff" size={19} /></View><View><Text style={[s.label, { fontSize: 16 }]}>私人档案</Text><Text style={[s.tiny, { marginTop: 5 }]}>本机保存 · 由你掌控</Text></View></View>
    <FormSection number="01" title="隐私与体验">
      <View style={{ backgroundColor: c.paper, borderRadius: 12, paddingHorizontal: 17 }}>{[
        { label: "设备解锁", description: "进入应用时验证身份", icon: "shield", value: data.settings.appLock, change: (value: boolean) => void appLock(value) },
        { label: "启动时隐藏内容", description: "隐藏代号、照片与记录", icon: "eye-off", value: data.settings.maskOnLaunch, change: (value: boolean) => void update({ maskOnLaunch: value }) },
        { label: "触感反馈", description: "操作时给予轻微回应", icon: "radio", value: data.settings.haptics, change: (value: boolean) => void update({ haptics: value }) },
      ].map((item, i) => <View key={item.label} style={[s.row, { gap: 13, minHeight: 83, paddingVertical: 17, borderTopWidth: i ? 1 : 0, borderColor: c.line }]}><Icon name={item.icon as IconName} size={19} color={c.muted} /><View style={{ flex: 1 }}><Text style={[s.label, { fontSize: 14 }]}>{item.label}</Text><Text style={[s.tiny, { marginTop: 5 }]}>{item.description}</Text></View><Switch accessibilityLabel={item.label} value={item.value} onValueChange={item.change} disabled={busy} trackColor={{ true: c.ink }} /></View>)}</View>
    </FormSection>
    <FormSection number="02" title="殿堂寄语"><Field label="写给自己的一句话" value={title} onChangeText={setTitle} placeholder="把心动，留给自己。" /><Button secondary disabled={busy} onPress={() => void update({ title: title.trim() || "把心动，留给自己。" }).then(success => { if (success) notify("寄语已保存"); })}>保存寄语</Button></FormSection>
    <FormSection number="03" title="档案管理">
      {!data.people.length && <View style={{ backgroundColor: c.paper, padding: 18, borderRadius: 12, marginBottom: 17 }}><Text style={s.label}>先看看示例</Text><Text style={[s.muted, { marginTop: 7, marginBottom: 17 }]}>虚构的人物与记录，带你了解每个页面。</Text><Button secondary onPress={() => void loadDemo()} disabled={busy}>载入示例内容</Button></View>}
      <Pressable accessibilityRole="button" accessibilityLabel="清空并开始自己的档案" onPress={() => setReset(true)} style={[s.between, { minHeight: 54, borderTopWidth: 1, borderBottomWidth: 1, borderColor: c.line }]}><Text style={[s.label, { color: c.red }]}>清空并开始自己的档案</Text><Icon name="arrow-up-right" size={16} color={c.red} /></Pressable>
    </FormSection>
    <View style={[s.row, { gap: 8, marginTop: 8, marginBottom: 6 }]}><Icon name="aperture" size={18} color={c.muted} /><Text style={[s.label, { color: c.muted, letterSpacing: -0.5 }]}>astra</Text><Text style={[s.tiny, { marginLeft: "auto" }]}>版本 2.0</Text></View>
    <Confirm visible={reset} title="开始空白档案？" message="当前版本的全部人物和记录将被清空。" onCancel={() => setReset(false)} onConfirm={() => void clear()} busy={busy} />
  </View></Screen>;
}
