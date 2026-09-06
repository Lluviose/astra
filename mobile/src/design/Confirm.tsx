import React from "react";
import { Modal, View, Text, Pressable } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Button, Icon, c, s } from "./ui";
export default function Confirm({
  visible,
  title,
  message,
  onCancel,
  onConfirm,
  busy = false,
  confirmLabel = "确认删除",
}: {
  visible: boolean;
  title: string;
  message: string;
  onCancel: () => void;
  onConfirm: () => void;
  busy?: boolean;
  confirmLabel?: string;
}) {
  const insets = useSafeAreaInsets();
  return (
    <Modal
      transparent
      visible={visible}
      animationType="fade"
      onRequestClose={() => { if (!busy) onCancel(); }}
    >
      <View
        style={{
          flex: 1,
          backgroundColor: "rgba(15,22,36,0.35)",
          alignItems: "center",
          justifyContent: "flex-end",
          padding: 17,
          paddingBottom: Math.max(17, insets.bottom),
        }}
      >
        <View
          accessibilityViewIsModal
          style={{
            maxWidth: 380,
            width: "100%",
            backgroundColor: c.paper,
            borderRadius: 22,
            padding: 25,
          }}
        >
          <View style={{ width: 32, height: 3, backgroundColor: c.line, borderRadius: 2, alignSelf: "center", marginBottom: 26 }} />
          <Text style={[s.h2, { fontSize: 23, lineHeight: 33 }]}>{title}</Text>
          <Text style={[s.muted, { marginTop: 12, marginBottom: 24 }]}>
            {message}
          </Text>
          <Button
            onPress={onConfirm}
            disabled={busy}
            style={{ backgroundColor: c.red }}
          >
            {confirmLabel}
          </Button>
          <Button
            onPress={onCancel}
            secondary
            disabled={busy}
            style={{ marginTop: 10 }}
          >
            取消
          </Button>
        </View>
      </View>
    </Modal>
  );
}
