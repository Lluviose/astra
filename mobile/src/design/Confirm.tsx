import React from "react";
import { Modal, View, Text, Pressable } from "react-native";
import { Button, c, s } from "./ui";
export default function Confirm({
  visible,
  title,
  message,
  onCancel,
  onConfirm,
  busy = false,
}: {
  visible: boolean;
  title: string;
  message: string;
  onCancel: () => void;
  onConfirm: () => void;
  busy?: boolean;
}) {
  return (
    <Modal
      transparent
      visible={visible}
      animationType="fade"
      onRequestClose={onCancel}
    >
      <View
        style={{
          flex: 1,
          backgroundColor: "rgba(15,22,36,0.35)",
          alignItems: "center",
          justifyContent: "center",
          padding: 28,
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
          <Text style={s.h2}>{title}</Text>
          <Text style={[s.muted, { marginTop: 12, marginBottom: 24 }]}>
            {message}
          </Text>
          <Button
            onPress={onConfirm}
            disabled={busy}
            style={{ backgroundColor: c.red }}
          >
            确认删除
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
