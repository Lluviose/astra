import React, { useState } from "react";
import { Keyboard, KeyboardAvoidingView, Platform, View } from "react-native";
import { router } from "expo-router";
import { Button, ErrorNote, Screen } from "./ui";
import Confirm from "./Confirm";

export default function FormScreen({
  children,
  title,
  saveLabel,
  error,
  busy,
  dirty,
  onSave,
}: {
  children: React.ReactNode;
  title: string;
  saveLabel: string;
  error: string;
  busy: boolean;
  dirty: boolean;
  onSave: () => void;
}) {
  const [discarding, setDiscarding] = useState(false);
  const leave = () => router.canGoBack() ? router.back() : router.replace("/");
  const close = () => {
    if (busy) return;
    Keyboard.dismiss();
    if (dirty) setDiscarding(true);
    else leave();
  };
  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === "ios" ? "padding" : undefined}>
      <Screen
        back
        title={title}
        right={<View />}
        onBack={close}
        footer={
          <>
            <ErrorNote message={error} />
            <Button icon="check" disabled={busy} onPress={() => { Keyboard.dismiss(); onSave(); }}>
              {busy ? "正在保存…" : saveLabel}
            </Button>
          </>
        }
      >
        {children}
      </Screen>
      <Confirm
        visible={discarding}
        title="放弃这次修改？"
        message="尚未保存的内容会丢失。你也可以继续编辑。"
        confirmLabel="放弃修改"
        onConfirm={leave}
        onCancel={() => setDiscarding(false)}
      />
    </KeyboardAvoidingView>
  );
}
