import React from "react";
import { View, Text } from "react-native";
import { Icon, c, s } from "../design/ui";
export default function FootprintMap() {
  return (
    <View
      style={{
        backgroundColor: c.blueSoft,
        borderRadius: 18,
        padding: 28,
        marginBottom: 25,
        flexDirection: "row",
        gap: 16,
        alignItems: "center",
      }}
    >
      <Icon name="map" size={30} color={c.blue} />
      <View style={{ flex: 1 }}>
        <Text style={s.label}>沿着记忆，再走一遍。</Text>
        <Text style={[s.muted, { marginTop: 7 }]}>
          iOS 版可在地图上浏览足迹，网页预览展示城市记录。
        </Text>
      </View>
    </View>
  );
}
