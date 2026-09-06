import React from "react";
import { View, Text, Pressable } from "react-native";
import { router } from "expo-router";
import { useApp } from "../data/store";
import { summary } from "../domain/model";
import FootprintMap from "../platform/FootprintMap";
import { Screen, Icon, Empty, c, s } from "../design/ui";
export default function Footprints() {
  const { data, hidden } = useApp();
  const { cities } = summary(data);
  return (
    <Screen back title="足迹">
      <Text style={[s.title, { marginTop: 12 }]}>走过的地方。</Text>
      <Text style={[s.muted, { marginTop: 9, marginBottom: 27 }]}>
        {cities.length} 个城市，串起你的故事。
      </Text>
      {!hidden && cities.length > 0 && <FootprintMap cities={cities} />}{" "}
      {!cities.length ? (
        <Empty
          title="第一站，去哪里？"
          description="在相处记录中填写城市，足迹会自动出现在这里。"
          icon="compass"
        />
      ) : (
        cities.map((city, i) => (
          <View
            key={city}
            style={[
              s.row,
              {
                gap: 18,
                paddingVertical: 22,
                borderBottomWidth: 1,
                borderBottomColor: c.line,
              },
            ]}
          >
            <Text style={[s.h2, { color: c.blue, width: 30 }]}>
              {String(i + 1).padStart(2, "0")}
            </Text>
            <View style={{ flex: 1 }}>
              <Text style={s.h2}>{hidden ? "已隐藏" : city}</Text>
              <Text style={[s.tiny, { marginTop: 5 }]}>
                {data.entries.filter((e) => e.city === city).length} 次相处
              </Text>
            </View>
            <Icon name="map-pin" color={c.muted} />
          </View>
        ))
      )}
    </Screen>
  );
}
